import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const PRODUCT_PAGE = "https://custom-wizard.pavilion.tech/pricing";
const SUPPORT_MESSAGE =
  "https://coop.pavilion.tech/new-message?username=support&title=Custom%20Wizard%20Support";
const MANAGER_CATEGORY =
  "https://coop.pavilion.tech/c/support/discourse-custom-wizard";

export default class SubscriptionService extends Service {
  @tracked subscribed = false;
  @tracked subscriptionType = "";
  @tracked businessSubscription = false;
  @tracked communitySubscription = false;
  @tracked standardSubscription = false;
  @tracked subscriptionAttributes = {};

  async init() {
    super.init(...arguments);
    await this.retrieveSubscriptionStatus();
  }

  async retrieveSubscriptionStatus() {
    let result = await ajax("/admin/wizards/subscription").catch(
      popupAjaxError
    );

    this.subscribed = true;
    this.subscriptionType = "business";
    this.subscriptionAttributes = result.subscription_attributes;
    this.businessSubscription = this.subscriptionType === "business";
    this.communitySubscription = this.subscriptionType === "community";
    this.standardSubscription = this.subscriptionType === "standard";
  }

  async updateSubscriptionStatus() {
    let result = await ajax(
      "/admin/wizards/subscription?update_from_remote=true"
    ).catch(popupAjaxError);

    this.subscribed = true;
    this.subscriptionType = "business";
    this.subscriptionAttributes = result.subscription_attributes;
    this.businessSubscription = this.subscriptionType === "business";
    this.communitySubscription = this.subscriptionType === "community";
    this.standardSubscription = this.subscriptionType === "standard";
  }

  get subscriptionCtaLink() {
    switch (this.subscriptionType) {
      case "none":
        return PRODUCT_PAGE;
      case "standard":
        return SUPPORT_MESSAGE;
      case "business":
        return SUPPORT_MESSAGE;
      case "community":
        return MANAGER_CATEGORY;
      default:
        return PRODUCT_PAGE;
    }
  }
}
