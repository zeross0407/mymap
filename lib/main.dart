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
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentsDirectory = await getApplicationDocumentsDirectory();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  int mode = 0;

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: MyMap(),
      ),
    );
  }
}

class MyMap extends StatefulWidget {
  const MyMap({super.key});

  @override
  State<MyMap> createState() => _MyMapState();
}

class _MyMapState extends State<MyMap> {
  // create the cache store as a field variable
  final Future<CacheStore> _cacheStoreFuture = _getCacheStore();

  /// Get the CacheStore as a Future. This method needs to be static so that it
  /// can be used to initialize a field variable.
  static Future<CacheStore> _getCacheStore() async {
    final dir = await getTemporaryDirectory();
    // Note, that Platform.pathSeparator from dart:io does not work on web,
    // import it from dart:html instead.
    return FileCacheStore('${dir.path}${Platform.pathSeparator}MapTiles');
  }

  LatLng? start_location;
  List<LatLng> routePoints = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) {},
    );
  }

  // Kiểm tra quyền truy cập vị trí
  Future<void> checkLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      // Hiển thị yêu cầu quyền nếu chưa có
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission is required")),
      );
    }
  }

  // Lấy vị trí hiện tại
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      setState(() {
        start_location = LatLng(position.latitude, position.longitude);
        if (start_location != null) {
          _mapController.move(
              start_location!, 15.0); // Di chuyển bản đồ về vị trí hiện tại
        }
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> fetchRoute(String start, String end) async {
    String url =
        'https://router.project-osrm.org/route/v1/driving/$start;$end?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final geometry = data['routes'][0]['geometry']['coordinates'];

        setState(() {
          search_data.clear();
          // Chuyển đổi danh sách tọa độ GeoJSON sang danh sách LatLng
          routePoints = geometry
              .map<LatLng>((point) => LatLng(point[1], point[0]))
              .toList();
        });
        calculateTotalDistance(routePoints);
      } else {
        debugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    }
  }

  double TotalDistance = 0;

// Hàm tính tổng quãng đường
  Future<void> calculateTotalDistance(List<LatLng> routeP) async {
    double totalDistance = 0.0;

    for (int i = 0; i < routeP.length - 1; i++) {
      // Lấy tọa độ của 2 điểm liên tiếp
      double startLatitude = routeP[i].latitude;
      double startLongitude = routeP[i].longitude;
      double endLatitude = routeP[i + 1].latitude;
      double endLongitude = routeP[i + 1].longitude;

      // Tính khoảng cách giữa hai điểm
      double distance = Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );

      totalDistance += distance; // Cộng dồn quãng đường
    }
    setState(() {
      TotalDistance = totalDistance; // Trả về tổng quãng đường
    });
  }

  List<Map<String, dynamic>> search_data = [];
  bool searching = false;
  final dio = Dio()
    ..options.headers['User-Agent'] =
        'YourAppName/1.0 (your-email@example.com)';

  Future<String> getPath() async {
    final cacheDirectory = await getTemporaryDirectory();
    return cacheDirectory.path;
  }

  LatLng init_location = const LatLng(21.0285, 105.8542);
  LatLng? end_location;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CacheStore>(
      future: _cacheStoreFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final cacheStore = snapshot.data!;
          return Stack(children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                  onTap: (tapPosition, point) {},
                  onMapReady: () {
                    checkLocationPermission();
                    _startTrackingLocation();
                  },
                  initialCenter: init_location, // Hà Nội
                  initialZoom: 8.0,
                  keepAlive: true),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  tileProvider: CachedTileProvider(
                    // use the store for your CachedTileProvider instance
                    store: cacheStore,
                  ),
                ),
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: const Color.fromARGB(255, 0, 255, 8),
                        strokeWidth: 5.0,
                      ),
                    ],
                  ),
                if (start_location != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: start_location!,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                if (end_location != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: end_location!,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
              child: Column(
                children: [
                  MySearchBar(
                    controller: _searchController,
                    onChanged: (text) {
                      setState(() {
                        _searchText = text;
                      });
                    },
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
                                      double.parse(search_data[index]["lat"]!
                                          .toString()),
                                      double.parse(search_data[index]["lon"]!
                                          .toString()));
                                  await showModalBottomSheet(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return Wrap(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12.0),
                                            child: ListView(
                                              shrinkWrap:
                                                  true, // Đảm bảo ListView chỉ chiếm diện tích đủ để chứa các mục
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
                                                      start_location = location;
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
                                                      end_location = location;
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
            if (end_location != null)
              Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
            Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
            if (!routePoints.isEmpty)
              Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
            if (is_following)
              Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 250, horizontal: 20),
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
                          border:
                              Border.all(color: Colors.grey.shade300, width: 1),
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
    );
  }

  bool is_loading = false;
  Position? _position;
  StreamSubscription? _positionStream;

  Position? _lastPosition; // Lưu vị trí trước đó
  DateTime? _lastUpdateTime; // Lưu thời gian trước đó
  double currentSpeed = 0; // Biến lưu vận tốc
  //bool is_running = false;
  /////////////////////////////////////////////////////////////////////////////////////////////////////////
  bool is_following = false;
  void _startTrackingLocation() {
    // setState(() {
    //   is_running = true;
    // });

    _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 20, // Cập nhật mỗi x mét
    )).listen((Position position) {
      final now = DateTime.now(); // Lấy thời gian hiện tại
      if (!is_following) return;
      setState(() {
        _position = position;
        start_location = LatLng(position.latitude, position.longitude);

        // Tính vận tốc
        if (_lastPosition != null && _lastUpdateTime != null) {
          final distanceInMeters = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          final timeInSeconds =
              now.difference(_lastUpdateTime!).inMilliseconds / 1000;

          currentSpeed = distanceInMeters / timeInSeconds; // m/s
          _checkRouteDeviation();
        }

        // Lưu lại vị trí và thời gian
        _lastPosition = position;
        _lastUpdateTime = now;
      });

      // Di chuyển bản đồ
      if (is_following) _mapController.move(start_location!, 15.0);
    });
  }

  double maxDeviationDistance = 50; // Ngưỡng khoảng cách tối đa (mét)
  void _checkRouteDeviation() {
    if (_position == null || routePoints.isEmpty) return;

    // Tính khoảng cách từ vị trí hiện tại đến từng điểm trên tuyến đường
    final currentLatLng = LatLng(_position!.latitude, _position!.longitude);
    const distanceCalculator = Distance();
    double? minDistance;

    for (var point in routePoints) {
      double distance = distanceCalculator(currentLatLng, point);
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
      }
    }

    // Nếu khoảng cách lớn hơn ngưỡng, cập nhật lại route
    if (minDistance != null && minDistance > maxDeviationDistance) {
      debugPrint("You are off route! Recalculating...");
      String currentPosition = "${_position!.longitude},${_position!.latitude}";
      String destination =
          "${routePoints.last.longitude},${routePoints.last.latitude}";
      fetchRoute(currentPosition, destination);
    }
  }
}
