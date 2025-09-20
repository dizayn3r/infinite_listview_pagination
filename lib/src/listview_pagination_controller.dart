import 'dart:async';
import 'package:logger/logger.dart';
import 'listview_pagination_state.dart';

typedef FetchPage<T> = Future<List<T>> Function(int page);

class PaginationController<T> {
  final FetchPage<T> fetchPage;
  final int pageSize;

  int _currentPage = 1;
  bool _isFetching = false;
  bool _disposed = false;
  PaginationState<T> _state = PaginationState<T>();

  final _stateController = StreamController<PaginationState<T>>.broadcast();
  final Logger _logger = Logger();

  Stream<PaginationState<T>> get stream => _stateController.stream;
  PaginationState<T> get state => _state;

  bool get isFetching => _isFetching;
  bool get isDisposed => _disposed;

  PaginationController({required this.fetchPage, this.pageSize = 20});

  Future<void> loadInitial() async {
    if (_isFetching || _disposed) return;

    _isFetching = true;
    _currentPage = 1;
    _state = PaginationState(status: PaginationStatus.loading);
    _logger.v('loadInitial: start (page=$_currentPage)');
    if (!_stateController.isClosed) _stateController.add(_state);

    try {
      final data = await fetchPage(_currentPage);
      _state = PaginationState(
        items: data,
        status: data.length < pageSize
            ? PaginationStatus.end
            : PaginationStatus.success,
      );
    } catch (e, st) {
      _logger.e('loadInitial: failed', e, st);
      // Keep existing items on failure, but change status to failure
      _state = _state.copyWith(status: PaginationStatus.failure);
    } finally {
      _isFetching = false;
      _logger.v('loadInitial: end (status=${_state.status}, items=${_state.items.length})');
      if (!_stateController.isClosed) _stateController.add(_state);
    }
  }

  Future<void> loadMore() async {
    if (_isFetching || _disposed || _state.status == PaginationStatus.end) return;

    _isFetching = true;
    _logger.v('loadMore: start (currentPage=$_currentPage)');
    if (!_stateController.isClosed) {
      _stateController.add(_state.copyWith(status: PaginationStatus.loading));
    }

    try {
      _currentPage++;
      final data = await fetchPage(_currentPage);

      _logger.d('loadMore: fetched ${data.length} items for page $_currentPage');

      if (data.isEmpty) {
        _state = _state.copyWith(status: PaginationStatus.end);
      } else {
        _state = _state.copyWith(
          items: [..._state.items, ...data],
          status: data.length < pageSize
              ? PaginationStatus.end
              : PaginationStatus.success,
        );
      }
    } catch (e, st) {
      _logger.e('loadMore: failed', e, st);
      _state = _state.copyWith(status: PaginationStatus.failure);
    } finally {
      _isFetching = false;
      _logger.v('loadMore: end (status=${_state.status}, totalItems=${_state.items.length})');
      if (!_stateController.isClosed) _stateController.add(_state);
    }
  }

  void dispose() {
    _disposed = true;
    _logger.v('dispose: closing controller');
    if (!_stateController.isClosed) _stateController.close();
  }

  /// Reset pagination state to initial. Does not dispose controller.
  void reset() {
    if (_disposed) return;
    _logger.v('reset: resetting pagination state');
    _currentPage = 1;
    _state = PaginationState<T>();
    if (!_stateController.isClosed) _stateController.add(_state);
  }
}
