import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vag_coding.dart';

class CodingCatalogService {
  static const fileExtension='otosinyalcatalog';
  static const _storageKey='otosinyal_signed_coding_catalog_v1';
  static const _publicKey=<int>[0x75,0x1f,0x30,0xd8,0x2b,0x66,0x11,0x47,0x95,0xe2,0x84,0x0c,0x3a,0xf8,0xa1,0x53,0x4d,0x8b,0x2e,0x79,0x12,0x46,0xca,0x90,0xb7,0x61,0xf0,0x39,0xa8,0x1d,0x55,0x0e];

  static Future<int?> pickVerifyAndInstall() async {
    final result=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:const [fileExtension],withData:true,allowMultiple:false);
    if(result==null||result.files.isEmpty)return null;
    final file=result.files.single;
    final bytes=file.bytes??(file.path==null?null:await File(file.path!).readAsBytes());
    if(bytes==null||bytes.isEmpty)throw const FormatException('Katalog dosyası okunamadı');
    final envelope=jsonDecode(utf8.decode(bytes));
    if(envelope is! Map||envelope['format']!='OTOSINYAL-CATALOG-1'||envelope['payload'] is! String||envelope['signature'] is! String)throw const FormatException('Geçersiz .otosinyalcatalog dosyası');
    final payloadBytes=base64Decode(envelope['payload'] as String);
    final signatureBytes=base64Decode(envelope['signature'] as String);
    final signature=Signature(signatureBytes,publicKey:SimplePublicKey(_publicKey,type:KeyPairType.ed25519));
    final valid=await Ed25519().verify(payloadBytes,signature:signature);
    if(!valid)throw const FormatException('Katalog imzası geçersiz veya dosya değiştirilmiş');
    final payload=jsonDecode(utf8.decode(payloadBytes));
    if(payload is! Map||payload['schemaVersion']!=1||payload['recipes'] is! List)throw const FormatException('Katalog şeması desteklenmiyor');
    final parsed=_parseRecipes((payload['recipes'] as List).whereType<Map>());
    await (await SharedPreferences.getInstance()).setString(_storageKey,jsonEncode(payload));
    return parsed.length;
  }

  static Future<List<VagCodingRecipe>> loadInstalled() async {
    final raw=(await SharedPreferences.getInstance()).getString(_storageKey);
    if(raw==null)return const [];
    try{final map=jsonDecode(raw);if(map is Map&&map['recipes'] is List)return _parseRecipes((map['recipes'] as List).whereType<Map>());}catch(_){}
    return const [];
  }

  static List<VagCodingRecipe> _parseRecipes(Iterable<Map> rows) {
    const locked={'03','15','05','25','2B','44'};
    final out=<VagCodingRecipe>[];
    for(final raw in rows){
      final map=Map<String,dynamic>.from(raw);
      final id='${map['id']??''}'.trim(), module='${map['moduleKey']??''}'.toUpperCase();
      final did='${map['did']??''}'.replaceAll(RegExp(r'[^0-9A-Fa-f]'),'').toUpperCase();
      final byteIndex=map['byteIndex'] is int?map['byteIndex'] as int:null;
      final bitIndex=map['bitIndex'] is int?map['bitIndex'] as int:null;
      final vehicles=(map['vehicleIds'] is List?(map['vehicleIds'] as List):const []).map((e)=>'$e').where((e)=>e.isNotEmpty).toSet();
      if(id.isEmpty||module.isEmpty||vehicles.isEmpty)continue;
      final longCoding=did.length==4&&byteIndex!=null&&byteIndex>=0&&bitIndex!=null&&bitIndex>=0&&bitIndex<=7;
      Set<String> stringSet(String key) => (map[key] is List ? (map[key] as List) : const [])
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      int intField(String key, int fallback) {
        final value = map[key];
        if (value is int) return value;
        final raw = '$value'.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
        if (raw.isEmpty) return fallback;
        return int.tryParse(raw, radix: 16) ?? fallback;
      }
      out.add(VagCodingRecipe(
        id:id,title:'${map['title']??id}',description:'${map['description']??''}',category:'${map['category']??'Diğer'}',
        moduleKey:module,moduleName:'${map['moduleName']??module}',requestId:'${map['requestId']??''}'.toUpperCase(),responseId:'${map['responseId']??''}'.toUpperCase(),
        kind:locked.contains(module)?CodingRecipeKind.unsupportedSafety:longCoding?CodingRecipeKind.longCodingBit:CodingRecipeKind.adaptation,
        did:longCoding?did:null,byteIndex:byteIndex,bitIndex:bitIndex,adaptationPath:map['adaptationPath']?.toString(),vehicleIds:vehicles,
        partNumbers:stringSet('partNumbers'),softwareVersions:stringSet('softwareVersions'),asamDatasets:stringSet('asamDatasets'),asamVersions:stringSet('asamVersions'),
        readService:intField('readService',0x22),writeService:map['writeService']==null?0x2E:intField('writeService',0x2E),diagnosticSession:intField('diagnosticSession',0x03),
        securityAccessLevel:map['securityAccessLevel'] is int?map['securityAccessLevel'] as int:null,securityProviderId:map['securityProviderId']?.toString(),
        experimental:map['experimental']!=false,writeEnabled:longCoding&&!locked.contains(module)&&map['writeEnabled']==true,risk:'${map['risk']??'Orta'}',
        evidence:'${map['evidence']??'İmzalı harici katalog'}',sourceResource:'${map['sourceResource']??''}',sourceRevision:'${map['sourceRevision']??''}',recovered:map['recovered']==true,
      ));
    }
    return out;
  }
}
