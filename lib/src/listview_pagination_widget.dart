import 'package:flutter/material.dart';
import 'listview_pagination_controller.dart';
import 'listview_pagination_state.dart';

typedef FooterBuilder<T> = Widget Function(
  BuildContext context,
  PaginationStatus status,
  List<T> items,
);

typedef HeaderBuilder<T> = Widget Function(
  BuildContext context,
  PaginationStatus status,
  List<T> items,
);

class PaginationListView<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? endWidget;
  final bool enablePullToRefresh;
  final VoidCallback? onRefreshCompleted; // ✅ NEW
  final HeaderBuilder<T>? headerBuilder; // ✅ NEW
  final FooterBuilder<T>? footerBuilder; // ✅ NEW

  const PaginationListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.loadingWidget,
    this.errorWidget,
    this.endWidget,
    this.enablePullToRefresh = true,
    this.onRefreshCompleted,
    this.headerBuilder,
    this.footerBuilder,
  });

  @override
  State<PaginationListView<T>> createState() => _PaginationListViewState<T>();
}

class _PaginationListViewState<T> extends State<PaginationListView<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.loadInitial();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        widget.controller.loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaginationState<T>>(
      stream: widget.controller.stream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.controller.state;

        if (state.status == PaginationStatus.loading &&
            state.items.isEmpty) {
          return widget.loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }

        if (state.status == PaginationStatus.failure &&
            state.items.isEmpty) {
          return widget.errorWidget ??
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Failed to load data"),
                    ElevatedButton(
                      onPressed: widget.controller.loadInitial,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              );
        }

        Widget listView = ListView.builder(
          controller: _scrollController,
          itemCount: state.items.length + 2,
          itemBuilder: (context, index) {

            // ✅ Header
            if (index == 0) {
              if (widget.headerBuilder != null) {
                return widget.headerBuilder!(
                  context,
                  state.status,
                  state.items,
                );
              }
              return const SizedBox.shrink();
            }

            // ✅ Items
            if (index <= state.items.length) {
              return widget.itemBuilder(
                context,
                state.items[index - 1],
              );
            }

            // ✅ Footer
            if (widget.footerBuilder != null) {
              return widget.footerBuilder!(
                context,
                state.status,
                state.items,
              );
            }

            // ✅ Show Loading/End indicators after list
            if (state.status == PaginationStatus.loading) {
              return const ListTile(
                leading: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text("Loading more..."),
              );
            } else if (state.status == PaginationStatus.end) {
              return widget.endWidget ??
                  const ListTile(
                    title: Center(child: Text("No more items")),
                  );
            } else {
              return const SizedBox.shrink();
            }
          },
        );

        // ✅ Wrap in RefreshIndicator if enabled
        if (widget.enablePullToRefresh) {
          return RefreshIndicator(
            onRefresh: () async {
              await widget.controller.loadInitial();
              widget.onRefreshCompleted?.call(); // ✅ trigger callback
            },
            child: listView,
          );
        } else {
          return listView;
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    widget.controller.dispose();
    super.dispose();
  }
}
