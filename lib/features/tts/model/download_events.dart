sealed class DownloadEvent {
  const DownloadEvent();
}

final class DownloadProgress extends DownloadEvent {
  final int bytesWritten;
  final int totalBytes;
  const DownloadProgress(this.bytesWritten, this.totalBytes);
}

final class DownloadVerifying extends DownloadEvent {
  const DownloadVerifying();
}

final class DownloadDone extends DownloadEvent {
  /// Path to the verified `.partial` file. Caller hands this to
  /// [ModelInstaller] for extraction + atomic rename.
  final String partialPath;
  const DownloadDone(this.partialPath);
}

final class DownloadCanceled extends DownloadEvent {
  const DownloadCanceled();
}

final class DownloadError extends DownloadEvent {
  final Object cause;
  final bool retryable;
  const DownloadError(this.cause, {required this.retryable});
}

class HashMismatch implements Exception {
  final String expected;
  final String actual;
  HashMismatch(this.expected, this.actual);
  @override
  String toString() => 'HashMismatch(expected=$expected, actual=$actual)';
}

class SizeOverflow implements Exception {
  final int limit;
  final int observed;
  SizeOverflow(this.limit, this.observed);
  @override
  String toString() => 'SizeOverflow(limit=$limit, observed=$observed)';
}

class NetworkException implements Exception {
  final Object original;
  NetworkException(this.original);
  @override
  String toString() => 'NetworkException($original)';
}

class PartialResumeRejected implements Exception {
  final int status;
  PartialResumeRejected(this.status);
  @override
  String toString() => 'PartialResumeRejected(status=$status)';
}
