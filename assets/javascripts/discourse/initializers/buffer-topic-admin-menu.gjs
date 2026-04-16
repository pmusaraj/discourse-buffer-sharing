import { apiInitializer } from "discourse/lib/api";
import BufferSharePreview from "../components/modal/buffer-share-preview";

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");

  if (!settings.buffer_sharing_enabled) {
    return;
  }

  api.addTopicAdminMenuButton((topic) => {
    const currentUser = api.getCurrentUser();
    if (!currentUser?.staff) {
      return;
    }

    return {
      action: () => {
        const modal = api.container.lookup("service:modal");
        modal.show(BufferSharePreview, { model: { topicId: topic.id } });
      },
      icon: "fab-buffer",
      className: "buffer-share-topic-button",
      label: "buffer_sharing.admin_menu_label",
    };
  });
});
