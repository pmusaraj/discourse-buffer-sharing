import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import BufferSharePreview from "../../components/modal/buffer-share-preview";

export default class BufferShareButton extends Component {
  @service modal;
  @service siteSettings;
  @service currentUser;

  get shouldShow() {
    return this.siteSettings.buffer_sharing_enabled && this.currentUser?.staff;
  }

  @action
  openBufferPreview() {
    this.modal.show(BufferSharePreview, {
      model: { topicId: this.args.outletArgs.topic.id },
    });
  }

  <template>
    {{#if this.shouldShow}}
      <DButton
        @action={{this.openBufferPreview}}
        @icon="fab-buffer"
        @label="buffer_sharing.share_button"
        class="btn-default buffer-share-button"
      />
    {{/if}}
  </template>
}
