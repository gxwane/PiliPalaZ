enum VideoSourceType { archive, pgc }

extension VideoSourceTypeExt on VideoSourceType {
  bool get isPgc => this == VideoSourceType.pgc;
}
