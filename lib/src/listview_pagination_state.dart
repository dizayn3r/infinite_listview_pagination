enum PaginationStatus { initial, loading, success, failure, end }

class PaginationState<T> {
  final List<T> items;
  final PaginationStatus status;

  PaginationState({
    this.items = const [],
    this.status = PaginationStatus.initial,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    PaginationStatus? status,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      status: status ?? this.status,
    );
  }
}
