# frozen_string_literal: true
class CustomWizard::TemplateValidator
  include HasErrors
  include ActiveModel::Model

  def initialize(data, opts = {})
    @data = data
    @opts = opts
    @subscription = CustomWizard::Subscription.new
  end

  def perform
    data = @data

    check_id(data, :wizard)
    check_required(data, :wizard)
    validate_after_signup
    validate_after_time
    validate_subscription(data, :wizard)

    return false if errors.any?

    data[:steps].each do |step|
      check_required(step, :step)
      validate_subscription(step, :step)
      validate_liquid_template(step, :step)

      if step[:fields].present?
        step[:fields].each do |field|
          validate_subscription(field, :field)
          check_required(field, :field)
          validate_liquid_template(field, :field)
          validate_guests(field, :field)
        end
      end
    end

    if data[:actions].present?
      data[:actions].each do |action|
        validate_subscription(action, :action)
        check_required(action, :action)
        validate_liquid_template(action, :action)
        validate_guests(action, :action)
      end
    end

    !errors.any?
  end

  def self.required
    { wizard: %w[id name steps], step: ["id"], field: %w[id type], action: %w[id type] }
  end

  private

  def check_required(object, type)
    self.class.required[type].each do |property|
      if object[property].blank?
        errors.add :base, I18n.t("wizard.validation.required", property: property)
      end
    end
  end

  def validate_subscription(object, type)
    
  end

  def check_id(object, type)
    if type === :wizard && @opts[:create] && CustomWizard::Template.exists?(object[:id])
      errors.add :base, I18n.t("wizard.validation.conflict", wizard_id: object[:id])
    end
  end

  def validate_guests(object, type)
    guests_permitted =
      @data[:permitted] &&
        @data[:permitted].any? { |m| m["output"]&.include?(CustomWizard::Wizard::GUEST_GROUP_ID) }
    return unless guests_permitted

    if type === :action && CustomWizard::Action::REQUIRES_USER.include?(object[:type])
      errors.add :base, I18n.t("wizard.validation.not_permitted_for_guests", object_id: object[:id])
    end

    if type === :field && CustomWizard::Field::REQUIRES_USER.include?(object[:type])
      errors.add :base, I18n.t("wizard.validation.not_permitted_for_guests", object_id: object[:id])
    end
  end

  def validate_after_signup
    return unless ActiveRecord::Type::Boolean.new.cast(@data[:after_signup])

    other_after_signup =
      CustomWizard::Template
        .list(setting: "after_signup")
        .select { |template| template["id"] != @data[:id] }

    if other_after_signup.any?
      errors.add :base,
                 I18n.t("wizard.validation.after_signup", wizard_id: other_after_signup.first["id"])
    end
  end

  def validate_after_time
    return unless ActiveRecord::Type::Boolean.new.cast(@data[:after_time])

    if ActiveRecord::Type::Boolean.new.cast(@data[:after_signup])
      errors.add :base, I18n.t("wizard.validation.after_signup_after_time")
      return
    end

    wizard = CustomWizard::Wizard.create(@data[:id]) if !@opts[:create]
    current_time = wizard.present? ? wizard.after_time_scheduled : nil
    new_time = @data[:after_time_scheduled]

    begin
      active_time = Time.parse(new_time.present? ? new_time : current_time).utc
    rescue ArgumentError
      invalid_time = true
    end

    if invalid_time || active_time.blank? || active_time < Time.now.utc
      errors.add :base, I18n.t("wizard.validation.after_time")
    end

    group_names = @data[:after_time_groups]
    if group_names.present?
      group_names.each do |group_name|
        unless Group.exists?(name: group_name)
          errors.add :base, I18n.t("wizard.validation.after_time_group", group_name: group_name)
        end
      end
    end
  end

  def validate_liquid_template(object, type)
    %w[description raw_description placeholder preview_template post_template].each do |field|
      if template = object[field]
        result = is_liquid_template_valid?(template)

        unless "valid" == result
          error =
            I18n.t(
              "wizard.validation.liquid_syntax_error",
              attribute: "#{object[:id]}.#{field}",
              message: result,
            )
          errors.add :base, error
        end
      end
    end
  end

  def is_liquid_template_valid?(template)
    begin
      Liquid::Template.parse(template)
      "valid"
    rescue Liquid::SyntaxError => error
      error.message
    end
  end
end
