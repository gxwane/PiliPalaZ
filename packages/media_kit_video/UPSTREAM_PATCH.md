# PiliPalaZ media_kit_video patch

This directory vendors `media_kit_video` 2.0.1 under its original MIT license.

The only source changes are disposal guards from upstream pull request
<https://github.com/media-kit/media-kit/pull/1356>. They prevent queued Android
and native video callbacks from calling `Player` APIs after disposal. Remove the
vendored package after an official release contains an equivalent fix and the
PiliPalaZ playback lifecycle stress test passes against that release.
