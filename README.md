# Discourse Buffer Sharing

Share Discourse topics to your social media channels through the [Buffer](https://buffer.com) API, directly from the topic share dialog or the topic admin menu.

## Features

- Adds a **Buffer** button to the share-topic modal and a **Share to Buffer** entry to the topic admin menu (staff only).
- Opens a preview modal where the title, excerpt, URL, and image are fetched from the server so the post text and image can be reviewed and edited before being queued.
- Prefills the post text as `title` / excerpt (up to ~100 characters, wrapped in ellipses) / absolute topic URL.
- Attaches the topic's image when present — either the first image in the OP or, if none exists and `generate_topic_og_image` is enabled, the generated OpenGraph image. This ensures image-required destinations like Pinterest accept the post.
- Lets staff pick which of their connected Buffer channels to queue the post to.

## Installation

Follow the [plugin installation guide](https://meta.discourse.org/t/install-a-plugin/19157).

## Configuration

1. In your [Buffer account](https://publish.buffer.com/), generate a personal API access token.
2. In Discourse, go to **Settings → Plugins** and:
   - Enable `buffer sharing enabled`.
   - Paste the token into `buffer api token`.
3. Ensure the Buffer account you're authenticating with has the channels you want to publish to connected.

## Usage

As a staff user on any public topic, either:

- Open the share dialog (the share button on a post) and click **Buffer**, or
- Open the topic admin wrench menu and select **Share to Buffer**.

Edit the post text if needed, pick one or more channels, and click **Send to Buffer**. The post is queued in Buffer — it does not publish immediately unless your Buffer channel is configured for instant publishing.

## Site settings

| Setting                | Description                                                                |
| ---------------------- | -------------------------------------------------------------------------- |
| `buffer_sharing_enabled` | Master switch for the plugin.                                              |
| `buffer_api_token`     | Buffer personal access token (stored as a secret). Required for the plugin to function. |

## License

MIT
