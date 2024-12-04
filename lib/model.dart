import 'package:hive/hive.dart';

part 'model.g.dart';

@HiveType(typeId: 0) // typeId phải là duy nhất
class Search_Model extends HiveObject {


  @HiveField(0)
  String? latitude;

  @HiveField(1)
  String? longitude; 

  @HiveField(2)
  String? name;

  Search_Model({
    this.latitude,
    this.longitude,
    this.name,

  });
}
