import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mymap/Repository.dart';
import 'package:mymap/search_bar.dart';
import 'package:mymap/ui_component.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import 'package:path_provider/path_provider.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';

void main() async {
  // Đảm bảo các binding của Flutter đã được khởi tạo.
  WidgetsFlutterBinding.ensureInitialized();

  // Chạy ứng dụng với widget MyMap.
  runApp(const MyMap());
}

class MyMap extends StatefulWidget {
  const MyMap({super.key});

  @override
  State<MyMap> createState() => _MyMapState();
}

class _MyMapState extends State<MyMap> {
// Khai báo biến Future để lưu trữ đối tượng CacheStore,
// đối tượng này sẽ được lấy từ phương thức _getCacheStore() khi hoàn thành.
  final Future<CacheStore> _cacheStoreFuture = _getCacheStore();

// Phương thức tĩnh _getCacheStore() trả về một đối tượng CacheStore.
// Đây là phương thức bất đồng bộ, sử dụng await để lấy thư mục tạm thời của ứng dụng.
  static Future<CacheStore> _getCacheStore() async {
    // Lấy thư mục tạm thời của ứng dụng (thư mục này thường dùng để lưu trữ dữ liệu tạm thời).
    final dir = await getTemporaryDirectory();

    // Trả về đối tượng FileCacheStore với đường dẫn đến thư mục "MapTiles" trong thư mục tạm thời.
    return FileCacheStore('${dir.path}${Platform.pathSeparator}MapTiles');
  }

  LatLng? start_location;
  List<LatLng> routePoints = [];
  final TextEditingController _searchController = TextEditingController();

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
  }

// Kiểm tra quyền truy cập vị trí và yêu cầu quyền nếu chưa được cấp.
  Future<void> checkLocationPermission() async {
    // Yêu cầu quyền truy cập vị trí từ người dùng.
    var status = await Permission.location.request();

    // Kiểm tra xem quyền đã được cấp hay chưa.
    if (status.isGranted) {
      // Nếu quyền được cấp, lấy vị trí hiện tại.
      _getCurrentLocation();
    } else {
      // Nếu quyền không được cấp, hiển thị thông báo yêu cầu quyền.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng bật định vị")),
      );
    }
  }

// Lấy vị trí hiện tại của người dùng.
  Future<void> _getCurrentLocation() async {
    try {
      // Lấy vị trí hiện tại với độ chính xác cao nhất.
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // Cập nhật vị trí và di chuyển bản đồ về vị trí hiện tại.
      setState(() {
        start_location = LatLng(position.latitude, position.longitude);

        // Nếu vị trí được xác định, di chuyển bản đồ đến vị trí đó với độ zoom 15.
        if (start_location != null) {
          _mapController.move(
              start_location!, 15.0); // Di chuyển bản đồ về vị trí hiện tại
        }
      });
    } catch (e) {
      // Nếu có lỗi trong quá trình lấy vị trí, in ra lỗi.
      print("Error getting location: $e");
    }
  }

// Lấy dữ liệu tuyến đường từ API OSRM và cập nhật danh sách các điểm trên tuyến đường.
  Future<void> fetchRoute(String start, String end) async {
    // Tạo URL yêu cầu tuyến đường giữa hai địa điểm 'start' và 'end'.
    String url =
        'https://router.project-osrm.org/route/v1/driving/$start;$end?overview=full&geometries=geojson';

    try {
      // Gửi yêu cầu GET đến API để lấy tuyến đường.
      final response = await http.get(Uri.parse(url));

      // Kiểm tra nếu yêu cầu thành công (mã trạng thái HTTP 200).
      if (response.statusCode == 200) {
        // Giải mã dữ liệu JSON nhận được từ API.
        final data = jsonDecode(response.body);
        final geometry = data['routes'][0]['geometry']['coordinates'];

        // Cập nhật trạng thái với danh sách các điểm trên tuyến đường.
        setState(() {
          search_data.clear(); // Xóa dữ liệu tìm kiếm trước đó (nếu có).

          // Chuyển đổi các tọa độ GeoJSON sang dạng LatLng (latitude, longitude).
          routePoints = geometry
              .map<LatLng>((point) => LatLng(point[1], point[0]))
              .toList();
        });

        // Tính toán tổng quãng đường từ danh sách các điểm tuyến đường.
        calculateTotalDistance(routePoints);
      } else {
        // Nếu mã trạng thái không phải 200, in lỗi trạng thái HTTP.
        debugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      // Nếu có lỗi trong quá trình gọi API, in lỗi.
      debugPrint('Error fetching route: $e');
    }
  }

  double TotalDistance = 0;

// Hàm tính tổng quãng đường giữa các điểm trong danh sách routeP.
  Future<void> calculateTotalDistance(List<LatLng> routeP) async {
    double totalDistance = 0.0; // Biến lưu trữ tổng quãng đường.

    // Duyệt qua danh sách các điểm, tính khoảng cách giữa các điểm liên tiếp.
    for (int i = 0; i < routeP.length - 1; i++) {
      // Lấy tọa độ của 2 điểm liên tiếp (start và end).
      double startLatitude = routeP[i].latitude;
      double startLongitude = routeP[i].longitude;
      double endLatitude = routeP[i + 1].latitude;
      double endLongitude = routeP[i + 1].longitude;

      // Tính khoảng cách giữa hai điểm sử dụng Geolocator.
      double distance = Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );

      // Cộng dồn quãng đường vào tổng quãng đường.
      totalDistance += distance;
    }

    // Cập nhật giá trị tổng quãng đường sau khi tính toán.
    setState(() {
      TotalDistance =
          totalDistance; // Lưu tổng quãng đường vào biến TotalDistance.
    });
  }

  List<Map<String, dynamic>> search_data = [];
  bool searching = false;

  LatLng init_location = const LatLng(21.0285, 105.8542);
  LatLng? end_location;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: FutureBuilder<CacheStore>(
          future: _cacheStoreFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final cacheStore = snapshot.data!;
              return Stack(children: [
                // Widget FlutterMap sử dụng để hiển thị bản đồ và các tính năng liên quan.
                FlutterMap(
                  // Controller của bản đồ, cho phép thao tác với bản đồ.
                  mapController: _mapController,

                  // Cấu hình các tùy chọn cho bản đồ, như sự kiện khi bản đồ được sẵn sàng.
                  options: MapOptions(
                    // Xử lý sự kiện khi người dùng nhấn vào bản đồ (tapPosition và point là tọa độ nhấn).
                    onTap: (tapPosition, point) {},

                    // Khi bản đồ đã sẵn sàng, kiểm tra quyền truy cập vị trí và bắt đầu theo dõi vị trí.
                    onMapReady: () {
                      checkLocationPermission(); // Kiểm tra quyền truy cập vị trí.
                      _startTrackingLocation(); // Bắt đầu theo dõi vị trí của người dùng.
                    },

                    // Vị trí và zoom ban đầu của bản đồ (ở đây là Hà Nội với mức zoom 8.0).
                    initialCenter: init_location,
                    initialZoom: 8.0,

                    // Giữ bản đồ sống khi không có tương tác.
                    keepAlive: true,
                  ),

                  // Các layer trên bản đồ.
                  children: [
                    // Layer chứa các tiles của bản đồ từ OpenStreetMap.
                    TileLayer(
                      urlTemplate:
                          "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", // URL của tiles.
                      tileProvider: CachedTileProvider(
                        // Cung cấp bộ nhớ cache để lưu trữ các tiles.
                        store:
                            cacheStore, // Sử dụng cacheStore để lưu trữ tiles đã tải.
                      ),
                    ),

                    // Nếu có các điểm tuyến đường (routePoints), vẽ polyline trên bản đồ.
                    if (routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points:
                                routePoints, // Các điểm tạo thành tuyến đường.
                            color: const Color.fromARGB(
                                255, 0, 255, 8), // Màu sắc đường.
                            strokeWidth: 5.0, // Độ rộng đường vẽ.
                          ),
                        ],
                      ),

                    // Nếu có vị trí bắt đầu (start_location), hiển thị marker đỏ tại đó.
                    if (start_location != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 80.0,
                            height: 80.0,
                            point: start_location!, // Vị trí marker.
                            child: const Icon(
                              Icons.location_pin, // Biểu tượng pin vị trí.
                              color: Colors.red, // Màu đỏ cho pin bắt đầu.
                              size: 40,
                            ),
                          ),
                        ],
                      ),

                    // Nếu có vị trí kết thúc (end_location), hiển thị marker xanh tại đó.
                    if (end_location != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 80.0,
                            height: 80.0,
                            point: end_location!, // Vị trí marker.
                            child: const Icon(
                              Icons.location_pin, // Biểu tượng pin vị trí.
                              color: Colors.blue, // Màu xanh cho pin kết thúc.
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                  child: Column(
                    children: [
                      MySearchBar(
                        controller: _searchController,
                        start_Search: (p0) async {
                          setState(() {
                            is_loading = true;
                          });
                          search_data = await getSuggestions(p0);
                          setState(() {
                            is_loading = false;
                          });
                        },
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      if (!search_data.isEmpty)
                        Container(
                          height: 300,
                          width: double.infinity,
                          decoration: my_decoration,
                          child: SingleChildScrollView(
                            child: Column(
                              children: List.generate(
                                search_data.length,
                                (index) {
                                  return GestureDetector(
                                    onTap: () async {
                                      setState(() {
                                        routePoints.clear();
                                      });
                                      LatLng location = LatLng(
                                          double.parse(search_data[index]
                                                  ["lat"]!
                                              .toString()),
                                          double.parse(search_data[index]
                                                  ["lon"]!
                                              .toString()));
                                      // hiển thị menu tùy chọn chức năng khi nhấn vào 1 kết quả tìm kiếm
                                      await showModalBottomSheet(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Wrap(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(12.0),
                                                child: ListView(
                                                  shrinkWrap: true,
                                                  children: [
                                                    ListTile(
                                                      title: const Text(
                                                          'Đi từ vị trí của bạn'),
                                                      onTap: () async {
                                                        Navigator.pop(context);
                                                        setState(() {
                                                          is_loading = true;
                                                        });
                                                        await _getCurrentLocation();
                                                        end_location = location;
                                                        await fetchRoute(
                                                            "${start_location!.longitude.toString()},${start_location!.latitude.toString()}",
                                                            "${end_location!.longitude.toString()},${end_location!.latitude.toString()}");
                                                        setState(() {
                                                          search_data.clear();
                                                          is_loading = false;
                                                        });
                                                      },
                                                    ),
                                                    ListTile(
                                                      title: const Text(
                                                          'Đặt làm vị trí bắt đầu'),
                                                      onTap: () {
                                                        setState(() {
                                                          start_location =
                                                              location;
                                                        });
                                                        _mapController.move(
                                                            location, 10);

                                                        Navigator.pop(context);
                                                      },
                                                    ),
                                                    ListTile(
                                                      title: const Text(
                                                          'Đặt làm vị trí kết thúc'),
                                                      onTap: () {
                                                        setState(() {
                                                          end_location =
                                                              location;
                                                        });
                                                        _mapController.move(
                                                            location, 10);
                                                        Navigator.pop(context);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      search_data.clear();
                                    },
                                    child: Container(
                                        alignment: Alignment.centerLeft,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10, horizontal: 20),
                                        child: Text(search_data[index]["name"]!
                                            .toString())),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      Expanded(child: Container())
                    ],
                  ),
                ),
                // nút ẩn , hiện tuyến đường
                if (end_location != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 40, horizontal: 20),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: FloatingActionButton(
                            onPressed: () {
                              if (routePoints.isEmpty) {
                                fetchRoute(
                                    "${start_location!.longitude.toString()},${start_location!.latitude.toString()}",
                                    "${end_location!.longitude.toString()},${end_location!.latitude.toString()}");
                              } else {
                                setState(() {
                                  routePoints.clear();
                                  search_data.clear();
                                });
                              }
                            },
                            child: Icon(routePoints.isNotEmpty
                                ? Icons.visibility
                                : Icons.visibility_off)),
                      )),
                // nút theo dõi
                Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 40, horizontal: 20),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FloatingActionButton(
                          onPressed: () {
                            _mapController.move(
                              start_location!,
                              13.0,
                            );
                            setState(() {
                              is_following = !is_following;
                            });
                          },
                          child: Icon(is_following
                              ? Icons.location_on
                              : Icons.location_off)),
                    )),
                // nếu đang xem tuyến đường , hiển thị độ dài quãng đường
                if (!routePoints.isEmpty)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 40, horizontal: 20),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 150,
                          height: 50,
                          decoration: my_decoration,
                          child: Center(
                            child: Text(
                                "${(TotalDistance / 1000).toStringAsFixed(2)} km",
                                style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                      )),
                // Nếu đang theo dõi , hiển thị vận tốc
                if (is_following)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 250, horizontal: 20),
                      child: Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 1),
                            ),
                            child: Text(
                              "${currentSpeed.toStringAsFixed(1)} m/s",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ))),
                if (is_loading || start_location == null) FadingTextLoading(),
              ]);
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            return FadingTextLoading();
          },
        ),
      ),
    );
  }

  bool is_loading = false;
  Position? _position;
  StreamSubscription? _positionStream;

  Position? _lastPosition; // Lưu vị trí trước đó
  DateTime? _lastUpdateTime; // Lưu thời gian trước đó
  double currentSpeed = 0; // Biến lưu vận tốc

  // Biến lưu trạng thái theo dõi vị trí của người dùng
  bool is_following = false;

// Hàm bắt đầu theo dõi vị trí của người dùng
  void _startTrackingLocation() {
    // Khởi tạo stream theo dõi vị trí người dùng.
    _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best, // Độ chính xác cao nhất
      distanceFilter: 20, // Cập nhật vị trí khi di chuyển ít nhất 20 mét
    )).listen((Position position) {
      final now = DateTime.now(); // Lấy thời gian hiện tại

      // Nếu không theo dõi, dừng xử lý
      if (!is_following) return;

      // Cập nhật lại vị trí và vị trí bắt đầu
      setState(() {
        _position = position; // Lưu vị trí mới
        start_location = LatLng(
            position.latitude, position.longitude); // Cập nhật vị trí bắt đầu

        // Tính vận tốc của người dùng
        if (_lastPosition != null && _lastUpdateTime != null) {
          final distanceInMeters = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          // Tính thời gian chênh lệch giữa 2 lần cập nhật
          final timeInSeconds =
              now.difference(_lastUpdateTime!).inMilliseconds / 1000;

          // Vận tốc = khoảng cách / thời gian
          currentSpeed = distanceInMeters / timeInSeconds; // m/s

          // Kiểm tra sự sai lệch giữa vị trí hiện tại và tuyến đường
          _checkRouteDeviation();
        }

        // Lưu lại vị trí và thời gian cập nhật lần này
        _lastPosition = position;
        _lastUpdateTime = now;
      });

      // Di chuyển bản đồ về vị trí hiện tại nếu đang theo dõi
      if (is_following) _mapController.move(start_location!, 15.0);
    });
  }

  // Ngưỡng khoảng cách tối đa (mét) để xác định sự sai lệch khỏi tuyến đường.
  double maxDeviationDistance = 50;

// Hàm kiểm tra sự sai lệch của người dùng so với tuyến đường đã vẽ.
  void _checkRouteDeviation() {
    // Nếu chưa có vị trí hiện tại hoặc không có điểm trên tuyến đường, không làm gì cả.
    if (_position == null || routePoints.isEmpty) return;

    // Lấy tọa độ hiện tại của người dùng.
    final currentLatLng = LatLng(_position!.latitude, _position!.longitude);

    // Khởi tạo đối tượng tính toán khoảng cách giữa các điểm.
    const distanceCalculator = Distance();
    double?
        minDistance; // Biến để lưu khoảng cách nhỏ nhất từ vị trí hiện tại đến các điểm trên tuyến đường.

    // Duyệt qua tất cả các điểm trên tuyến đường và tính khoảng cách từ vị trí hiện tại đến từng điểm.
    for (var point in routePoints) {
      double distance = distanceCalculator(currentLatLng, point);

      // Cập nhật minDistance nếu tìm thấy khoảng cách nhỏ hơn.
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
      }
    }

    // Nếu khoảng cách nhỏ nhất lớn hơn ngưỡng cho phép, tính lại tuyến đường.
    if (minDistance != null && minDistance > maxDeviationDistance) {
      //debugPrint("You are off route! Recalculating...");

      // Chuyển đổi vị trí hiện tại và điểm đích thành chuỗi để truyền vào API tính lại tuyến đường.
      String currentPosition = "${_position!.longitude},${_position!.latitude}";
      String destination =
          "${routePoints.last.longitude},${routePoints.last.latitude}";

      // Gọi hàm fetchRoute để tính lại tuyến đường từ vị trí hiện tại đến điểm đích.
      fetchRoute(currentPosition, destination);
    }
  }
}
