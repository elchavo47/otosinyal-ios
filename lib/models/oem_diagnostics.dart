class UdsIdentityItem {
  final String label;
  final String did;
  final String value;
  final bool supported;
  final String? error;
  const UdsIdentityItem({required this.label,required this.did,required this.value,required this.supported,this.error});
}

class OemDiscoveryState {
  final List<String> respondingCanIds;
  final List<UdsIdentityItem> identities;
  final String? catalogName;
  final int catalogEcuCount;
  final int catalogDidCount;
  final int verifiedDidCount;
  final int catalogRoutineCount;
  final bool catalogExperimental;
  const OemDiscoveryState({this.respondingCanIds=const[],this.identities=const[],this.catalogName,this.catalogEcuCount=0,this.catalogDidCount=0,this.verifiedDidCount=0,this.catalogRoutineCount=0,this.catalogExperimental=false});
}
