import Component from "@glimmer/component";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking"
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { concat } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import avatar from "discourse/helpers/avatar";
import DiscourseURL from "discourse/lib/url";
import DMenu from "float-kit/components/d-menu";
import DButton from "discourse/components/d-button";
import DButtonTooltip from "discourse/components/d-button-tooltip";
import DTooltip from "float-kit/components/d-tooltip";
import Category from "discourse/models/category";
import emoji from "discourse/helpers/emoji";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import UserStatusModal from "discourse/components/modal/user-status";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";

const USER_DRAFTS_CHANGED_EVENT = "user-drafts:changed";

export default class ComposeCenter extends Component {
  @service currentUser;
  @service router;
  @service modal;
  @service composer;
  @service userStatus;
  @service appEvents;
  @service siteSettings;

  @tracked banner = null;
  @tracked pendingPostCount = null;
  @tracked draftCount = this.currentUser?.draft_count;
  @tracked composeCenterShown = false;

  constructor() {
    super(...arguments);

    if (this.currentUser !== null) {
      const currentUserUrl = "/u/" + this.currentUser.username + "/card.json";

      ajax(currentUserUrl).then((data) => {
        this.updateUserData(data.user);
      });
    }

    this.appEvents.on(
      USER_DRAFTS_CHANGED_EVENT,
      this,
      this._updateDraftCount
    );
  }

  // User Section

  updateUserData(user) {
    this.banner = user.card_background_upload_url;
    this.pendingPostCount = user.pending_posts_count;
  }

  teardown() {
    this.appEvents.off(
      USER_DRAFTS_CHANGED_EVENT,
      this,
      this._updateDraftCount
    );
  }

  _updateDraftCount() {
    this.draftCount = this.currentUser.draft_count;
  }

  get hasDraft() {
    return this.draftCount > 0;
  }

  get hasPendingPost() {
    return this.pendingPostCount > 0;
  }

  get profileProfileButtonTitle() {
    return I18n.t(themePrefix("composecenter.profile_button_title"));
  }

  get profileAccountButtonTitle() {
    return I18n.t(themePrefix("composecenter.account_button_title"));
  }

  get pendingPostButtonLabel() {
    return I18n.t(themePrefix("composecenter.pending_post_button_label"));
  }

  get dMenuLabel() {
    return I18n.t(themePrefix("composecenter.menu_button_label"));
  }

  @action
  profileLink() {
    DiscourseURL.routeTo("/my/preferences/profile");
    this.dMenu.close();
  }

  @action
  draftLink() {
    DiscourseURL.routeTo("/my/activity/drafts");
    this.dMenu.close();
  }

  @action
  pendingPostLink() {
    DiscourseURL.routeTo("/my/activity/pending");
    this.dMenu.close();
  }

  @action
  setUserStatusClick() {
    this.modal.show(UserStatusModal, {
      model: {
        status: this.currentUser.status,
        pauseNotifications: this.currentUser.isInDoNotDisturb(),
        saveAction: (status, pauseNotifications) =>
          this.userStatus.set(status, pauseNotifications),
        deleteAction: () => this.userStatus.clear(),
      },
    });
  }

  // New Topic

  canCreateTopic = this.currentUser?.can_create_topic;

  topic = this.router.currentRouteName.includes("topic")
    ? getOwner(this).lookup("controller:topic")
    : null;

  get userHasDraft() {
    return this.currentUser?.get("has_topic_draft");
  }

  get currentTag() {
    if (this.router.currentRoute.attributes?.tag?.id) {
      return [
        this.router.currentRoute.attributes?.tag?.id,
        ...(this.router.currentRoute.attributes?.additionalTags ?? []),
      ]
        .filter(Boolean)
        .filter((t) => !["none", "all"].includes(t))
        .join(",");
    } else {
      return this.topic?.model?.tags?.join(",");
    }
  }

  get currentCategory() {
    return (
      this.router.currentRoute.attributes?.category ||
      (this.topic?.model?.category_id
        ? Category.findById(this.topic?.model?.category_id)
        : null)
    );
  }

  get canCreateTopicWithTag() {
    return (
      !this.router.currentRoute.attributes?.tag?.staff ||
      this.currentUser?.staff
    );
  }

  get canCreateTopicWithCategory() {
    return !this.currentCategory || this.currentCategory?.permission;
  }

  get createTopicDisabled() {
    if (this.userHasDraft) {
      return false;
    } else {
      return (
        !this.canCreateTopic ||
        !this.canCreateTopicWithCategory ||
        !this.canCreateTopicWithTag
      );
    }
  }

  get createTopicLabel() {
    return this.userHasDraft
      ? I18n.t("topic.open_draft")
      : settings.new_topic_button_text;
  }

  get createTopicTitle() {
    if (!this.userHasDraft && settings.new_topic_button_title.length) {
      return settings.new_topic_button_title;
    } else {
      return this.createTopicLabel;
    }
  }

  get showDisabledTooltip() {
    return this.createTopicDisabled && !this.currentCategory?.read_only_banner;
  }

  @action
  createTopic() {
    this.composer.openNewTopic({
      preferDraft: true,
      category: this.currentCategory,
      tags: this.currentTag,
    });

    this.dMenu.close();
  }

  // New Message

  @action
  newMessage() {
    this.composer.openNewMessage({
      title: "",
      body: "",
    });

    this.dMenu.close();
  }

  // New Chat Message

  @action
  newChatMessage() {
    this.modal.show(ChatModalNewMessage);
  }

  // Show Compose Center

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  showComposeCenter() {
    this.composeCenterShown = true;
  }

  <template>
    <DMenu
      @arrow={{false}}
      @identifier="compose-center"
      @interactive={{true}}
      @triggers="click"
      @id="create-topic"
      @icon="pencil-alt"
      @label={{this.dMenuLabel}}
      @action={{this.showComposeCenter}}
      @modalForMobile={{true}}
      @inline={{true}}
      @onRegisterApi={{this.onRegisterApi}}
    >
      <:content>
        <div class="compose-center">
          {{#if this.currentUser}}
    
            {{#if this.banner}}
              <div
                class="compose-center__banner has-banner"
                style={{htmlSafe (concat "background-image: url('" this.banner "')")}}
              >
                <div
                  class={{concatClass
                    (if this.hasDraft
                      "has-draft"
                    )
                    "quick-buttons"
                  }}
                >
                  {{#if this.hasDraft}}
                    <DButton
                      @class="btn btn-default btn-small"
                      @icon="pencil-alt"
                      @translatedLabel={{i18n
                        "js.sidebar.sections.community.links.my_posts.content_drafts"
                      }}
                      @action={{this.draftLink}}
                    >
                      <span class="draft-count">{{this.draftCount}}</span>
                    </DButton>
                  {{/if}}
                  <DButton
                    @class="btn btn-default btn-small btn-icon no-text"
                    @icon="pencil-alt"
                    @translatedTitle={{this.profileProfileButtonTitle}}
                    @action={{this.profileLink}}
                  />
                </div>
              </div>
            {{else}}
              <div
                class="compose-center__banner avatar-banner"
              >
                <div
                  class={{concatClass
                    (if this.hasDraft
                      "has-draft"
                    )
                    "quick-buttons"
                  }}
                >
                  {{#if this.hasDraft}}
                    <DButton
                      @class="btn btn-default btn-small"
                      @icon="pencil-alt"
                      @translatedLabel={{i18n
                        "js.sidebar.sections.community.links.my_posts.content_drafts"
                      }}
                      @action={{this.draftLink}}
                    >
                      <span class="draft-count">{{this.draftCount}}</span>
                    </DButton>
                  {{/if}}
                  <DButton
                    @class="btn btn-default btn-small btn-icon no-text"
                    @icon="pencil-alt"
                    @translatedTitle={{this.profileProfileButtonTitle}}
                    @action={{this.profileLink}}
                  />
                </div>
                {{avatar this.currentUser "huge"}}
              </div>
            {{/if}}
    
            <div class="compose-center__avatar">
              <a 
                href="/my/preferences/account" 
                class="profile-avatar" 
                title={{this.profileAccountButtonTitle}}
              >
                {{avatar this.currentUser "huge"}}
                {{icon "pencil-alt"}}
              </a>
              {{#if this.siteSettings.enable_user_status}}
                {{#if this.currentUser.status}}
                  <DTooltip>
                    <:trigger>
                      <DButton
                        @action={{this.setUserStatusClick}}
                        class="btn-flat has-user-status-btn"
                      >
                        {{emoji this.currentUser.status.emoji}}
                      </DButton>
                    </:trigger>
                    <:content>
                      {{this.currentUser.status.description}}
                    </:content>
                  </DTooltip>
                {{else}}
                  <DButton
                    @action={{this.setUserStatusClick}}
                    class="btn-flat set-user-status-btn"
                  >
                    {{icon "plus-circle"}}
                  </DButton>
                {{/if}}
              {{/if}}
            </div>
    
            <div class="compose-center__publish">
              <div class="new-topic-publish">
                <DButtonTooltip>
                  <:button>
                    <DButton
                      @action={{this.createTopic}}
                      @translatedLabel={{this.createTopicLabel}}
                      @translatedTitle={{this.createTopicTitle}}
                      @icon={{settings.new_topic_button_icon}}
                      id="publish-create-topic"
                      class={{concatClass
                        (if this.userHasDraft "open-draft")
                        "btn-primary create-topic"
                      }}
                      disabled={{this.createTopicDisabled}}
                    />
                  </:button>
                  <:tooltip>
                    {{#if this.showDisabledTooltip}}
                      <DTooltip
                        @icon="info-circle"
                        @content={{i18n (themePrefix "button_disabled_tooltip")}}
                      />
                    {{/if}}
                  </:tooltip>
                </DButtonTooltip>
              </div>
              <div class="new-message-chat-publish">
                {{#if this.currentUser.can_send_private_messages}}
                  <DButton
                    @class="btn btn-primary new-message"
                    @icon="envelope"
                    @translatedLabel={{i18n "js.user.private_message"}}
                    @action={{this.newMessage}}
                  />
                {{/if}}
                {{#if this.siteSettings.chat_enabled}}
                  {{#if this.currentUser.can_direct_message}}
                    <DButton
                      @class="btn btn-primary new-chat-message"
                      @icon="comment"
                      @translatedLabel={{i18n "js.chat.title_capitalized"}}
                      @action={{this.newChatMessage}}
                    />
                  {{/if}}
                {{/if}}
              </div>
              {{#if this.hasPendingPost}}
                <div class="pending-posts">
                  <DButton
                    @class="btn btn-transparent btn-pending"
                    @icon="clock"
                    @translatedLabel={{this.pendingPostButtonLabel}}
                    @action={{this.pendingPostLink}}
                  >
                    <span class="pending-post-count">
                      {{this.pendingPostCount}}
                    </span>
                  </DButton>
                </div>
              {{/if}}
            </div>
          {{/if}}
        </div>
      </:content>
    </DMenu>
  </template>
}
