import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { buildBufferShareText } from "../../lib/buffer-share-text";

export default class BufferSharePreview extends Component {
  @service toasts;

  @tracked channels = [];
  @tracked loadingChannels = true;
  @tracked loadingPreview = true;
  @tracked sending = false;
  @tracked defaultText = "";
  @tracked imageUrl = null;
  isSelected = (channelId) => {
    return !!this._selectedIds[channelId];
  };
  @tracked _selectedIds = {};

  @tracked _text = null;

  constructor() {
    super(...arguments);
    this.loadChannels();
    this.loadPreview();
  }

  get text() {
    return this._text ?? this.defaultText;
  }

  set text(value) {
    this._text = value;
  }

  get selectedChannels() {
    return this.channels.filter((c) => this._selectedIds[c.id]);
  }

  get canSend() {
    return this.selectedChannels.length > 0 && !this.sending;
  }

  async loadPreview() {
    try {
      const result = await ajax("/buffer-sharing/preview", {
        data: { topic_id: this.args.model.topicId },
      });
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      this.defaultText = buildBufferShareText({
        title: result.title,
        excerpt: result.excerpt,
        url: result.url,
      });
      this.imageUrl = result.image_url;
    } catch (error) {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      popupAjaxError(error);
    } finally {
      if (!this.isDestroying && !this.isDestroyed) {
        this.loadingPreview = false;
      }
    }
  }

  async loadChannels() {
    try {
      const result = await ajax("/buffer-sharing/channels");
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      this.channels = result.channels;
    } catch {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      this.channels = [];
    } finally {
      if (!this.isDestroying && !this.isDestroyed) {
        this.loadingChannels = false;
      }
    }
  }

  @action
  toggleChannel(channelId) {
    this._selectedIds = {
      ...this._selectedIds,
      [channelId]: !this._selectedIds[channelId],
    };
  }

  @action
  async confirm() {
    if (!this.canSend) {
      return;
    }

    this.sending = true;

    try {
      await ajax("/buffer-sharing/share", {
        type: "POST",
        data: {
          topic_id: this.args.model.topicId,
          text: this.text,
          channels: this.selectedChannels.map((c) => ({
            id: c.id,
            service: c.service,
          })),
        },
      });

      this.toasts.success({
        duration: "short",
        data: { message: i18n("buffer_sharing.success") },
      });

      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.sending = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "buffer_sharing.modal_title"}}
      @closeModal={{@closeModal}}
      class="buffer-share-preview-modal"
    >
      <:body>
        <label class="buffer-share-preview-modal__label">
          {{i18n "buffer_sharing.preview_label"}}
        </label>
        <ConditionalLoadingSpinner @condition={{this.loadingPreview}}>
          <Textarea
            @value={{this.text}}
            class="buffer-share-preview-modal__textarea"
          />

          {{#if this.imageUrl}}
            <label class="buffer-share-preview-modal__label">
              {{i18n "buffer_sharing.image_label"}}
            </label>
            <img
              src={{this.imageUrl}}
              class="buffer-share-preview-modal__image"
              alt=""
            />
          {{/if}}
        </ConditionalLoadingSpinner>

        <label class="buffer-share-preview-modal__label">
          {{i18n "buffer_sharing.channels_label"}}
        </label>

        <ConditionalLoadingSpinner @condition={{this.loadingChannels}}>
          {{#if this.channels.length}}
            <div class="buffer-share-preview-modal__channels">
              {{#each this.channels as |channel|}}
                <label class="buffer-share-preview-modal__channel">
                  <input
                    type="checkbox"
                    checked={{this.isSelected channel.id}}
                    {{on "change" (fn this.toggleChannel channel.id)}}
                  />
                  <span
                    class="buffer-share-preview-modal__channel-name"
                  >{{channel.displayName}}</span>
                  <span
                    class="buffer-share-preview-modal__channel-service"
                  >{{channel.service}}</span>
                </label>
              {{/each}}
            </div>
          {{else}}
            <p>{{i18n "buffer_sharing.no_channels"}}</p>
          {{/if}}
        </ConditionalLoadingSpinner>
      </:body>
      <:footer>
        <DButton
          @label="buffer_sharing.confirm"
          @action={{this.confirm}}
          @isLoading={{this.sending}}
          @disabled={{not this.canSend}}
          class="btn-primary"
        />
        <DButton @label="buffer_sharing.cancel" @action={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
