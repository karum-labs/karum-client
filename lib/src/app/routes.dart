/// Arguments for a workspace route.
class WorkspaceArgs {
  const WorkspaceArgs({this.showCoach = false});

  /// Whether to open the first-run coach after the campaign loads.
  final bool showCoach;
}
