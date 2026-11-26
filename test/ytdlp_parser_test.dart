import 'package:flutter_test/flutter_test.dart';
import 'package:klipfetch/models/media_platform.dart';
import 'package:klipfetch/services/ytdlp_service.dart';

void main() {
  group('isYouTubePlaylistUrl', () {
    test('detects YouTube playlist links cleanly', () {
      expect(
        isYouTubePlaylistUrl(
          'https://www.youtube.com/playlist?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf',
        ),
        isTrue,
      );
      expect(
        isYouTubePlaylistUrl(
          'https://youtu.be/dQw4w9WgXcQ?list=PL12345',
        ),
        isTrue,
      );
      expect(
        isYouTubePlaylistUrl(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        isFalse,
      );
      expect(
        isYouTubePlaylistUrl(
          'https://www.instagram.com/reel/Cxyz123/',
        ),
        isFalse,
      );
    });
  });

  group('YtDlpService Phase 3 parsing', () {
    test('parses flat playlist JSON into selectable PlaylistEntry list', () {
      const playlistJson = '''
      {
        "_type": "playlist",
        "title": "Rust & Flutter Tutorials",
        "uploader": "OpenSelena",
        "webpage_url": "https://www.youtube.com/playlist?list=PL123",
        "entries": [
          {
            "id": "vid1",
            "title": "Episode 1",
            "duration": 180.0,
            "thumbnail": "https://i.ytimg.com/vi/vid1/hqdefault.jpg"
          },
          {
            "id": "vid2",
            "title": "Episode 2",
            "webpage_url": "https://www.youtube.com/watch?v=vid2",
            "duration": 240.0
          }
        ]
      }
      ''';

      final parsed = YtDlpService.parseYtDlpInfoJson(
        playlistJson,
        MediaPlatform.youtube,
        'https://www.youtube.com/playlist?list=PL123',
      );

      expect(parsed.isPlaylist, isTrue);
      expect(parsed.mediaType, 'playlist');
      expect(parsed.title, 'Rust & Flutter Tutorials');
      expect(parsed.playlistEntries.length, 2);
      expect(parsed.playlistEntries[0].index, 1);
      expect(
        parsed.playlistEntries[0].url,
        'https://www.youtube.com/watch?v=vid1',
      );
      expect(parsed.playlistEntries[1].title, 'Episode 2');
      expect(
        parsed.qualities.map((q) => q.label).toList(),
        containsAll(['2160p', '1440p', '1080p', '720p', '480p']),
      );
    });

    test('parses 4K/2K/1080p/480p qualities and available subtitles', () {
      const videoJson = '''
      {
        "title": "4K Scenic Drone",
        "uploader": "ScenicChannel",
        "duration": 90.0,
        "webpage_url": "https://www.youtube.com/watch?v=4kdemo",
        "formats": [
          {"format_id": "135", "height": 480, "width": 854, "vcodec": "avc1", "ext": "mp4"},
          {"format_id": "247", "height": 720, "width": 1280, "vcodec": "vp9", "ext": "webm"},
          {"format_id": "299", "height": 1080, "width": 1920, "vcodec": "avc1", "ext": "mp4"},
          {"format_id": "271", "height": 1440, "width": 2560, "vcodec": "vp9", "ext": "webm"},
          {"format_id": "313", "height": 2160, "width": 3840, "vcodec": "vp9", "ext": "webm"}
        ],
        "subtitles": {
          "id": [{"ext": "vtt"}],
          "live_chat": [{"ext": "json"}]
        },
        "automatic_captions": {
          "en": [{"ext": "srt"}]
        }
      }
      ''';

      final parsed = YtDlpService.parseYtDlpInfoJson(
        videoJson,
        MediaPlatform.youtube,
        'https://www.youtube.com/watch?v=4kdemo',
      );

      expect(parsed.isPlaylist, isFalse);
      expect(
        parsed.qualities.map((q) => q.label).toList(),
        ['2160p', '1440p', '1080p', '720p', '480p'],
      );
      expect(
        parsed.qualities.first.formatId,
        'bv*[height<=2160]+ba/b[height<=2160]/b',
      );
      expect(parsed.availableSubtitles, ['en', 'id']);
    });
  });
}
