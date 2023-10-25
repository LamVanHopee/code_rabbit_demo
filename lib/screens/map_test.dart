import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:metro_app/common/const.dart';
import 'package:metro_app/common/enums.dart';
import 'package:metro_app/di_container.dart';
import 'package:metro_app/entities/congestion_info.dart';
import 'package:metro_app/entities/line.dart';
import 'package:metro_app/entities/line_external_link.dart';
import 'package:metro_app/entities/line_station.dart';
import 'package:metro_app/entities/station_external_link.dart';
import 'package:metro_app/entities/train.dart';
import 'package:metro_app/entities/train_timetable.dart';
import 'package:metro_app/repositories/app_repository.dart';
import 'package:metro_app/repositories/congestion_repository.dart';
import 'package:metro_app/repositories/line_stations_repository.dart';
import 'package:metro_app/repositories/lines_repository.dart';
import 'package:metro_app/repositories/trains_repository.dart';
import 'package:metro_app/services/app_tracker.dart';
import 'package:metro_app/services/event_name.dart';
import 'package:metro_app/services/logger.dart';
import 'package:metro_app/services/navigation_service.dart';
import 'package:metro_app/utils/sharedpreference_utils.dart';
import 'package:metro_app/views/base/screens/base_app_screen.dart';
import 'package:metro_app/views/base/screens/base_screen.dart';
import 'package:metro_app/widgets/atomic/atoms/line_icon.dart';
import 'package:metro_app/widgets/atomic/atoms/station_icon.dart';
import 'package:metro_app/widgets/atomic/atoms/train_icon.dart';
import 'package:metro_app/widgets/atomic/molecules/stripe.dart';
import 'package:metro_app/widgets/atomic/organisms/congestion_info_dialog.dart';
import 'package:metro_app/widgets/atomic/organisms/congestion_note_dialog.dart';
import 'package:metro_app/widgets/atomic/organisms/cupertino_dialog_custom.dart';
import 'package:metro_app/widgets/atomic/organisms/dialog_custom.dart';
import 'package:metro_app/widgets/atomic/organisms/error_dialog.dart';
import 'package:metro_app/widgets/atomic/organisms/externalLineInfoDialog.dart';
import 'package:metro_app/widgets/atomic/organisms/external_link_loading_dialog.dart';
import 'package:metro_app/widgets/atomic/organisms/line_station_master_dialog.dart';
import 'package:metro_app/widgets/atomic/organisms/map_setting_dialog.dart';
import 'package:metro_app/widgets/atomic/organisms/train_position_message.dart';
import 'package:metro_app/widgets/styles/metro_colors.dart';
import 'package:metro_app/widgets/styles/metro_images.dart';
import 'package:metro_app/widgets/styles/metro_text_styles.dart';
import 'package:metro_app/widgets/utils/congestion_utils.dart';
import 'package:metro_app/widgets/utils/map_function.dart';
import 'package:metro_app/widgets/utils/map_painter.dart';
import 'package:metro_app/widgets/utils/scroll_behavior.dart';
import 'package:metro_app/widgets/utils/size_config.dart';
import 'package:metro_app/widgets/utils/string_utils.dart';
import 'package:provider/provider.dart';

import 'base/base_common_map_bloc.dart';
import 'base/base_map_screen_state.dart';
import 'base/base_stateful_widget.dart';

typedef OnViewIntersect = Function(
    LineStation horizontalLineStation, LineStation verticalLineStation);

typedef GetTimetable = Future<List<TrainTimetable>> Function(Train train);

bool mapScreenisOpened = false;

/// Map bloc state
/// [ERROR] Show dialog about error detail
/// [IDLE] Do nothing
/// [NETWORK_ERROR] Show network error dialog
/// [SUCCESSFULLY] Perform something successful
/// [LOADING] Processing
/// [TIME_OUT] Handling too long
/// [STATION_MAP_ERROR] Direction to web is failed
// enum MapState { ERROR, IDLE, SUCCESSFULLY, NETWORK_ERROR, LOADING, TIME_OUT, STATION_MAP_ERROR }

/// 路線状況詳細画面
/// HOMEから起動される
class MapScreen extends BaseAppScreen {
  const MapScreen(GlobalKey<NavigatorState> navigatorKey,
      {@required this.lineStationId, String shortCutMode, bool displayAdvertisedBanner, Key key})
      : super(navigatorKey, shortCutMode: shortCutMode, displayAdvertisedBanner: displayAdvertisedBanner, key: key);

  final String lineStationId; // 中央に表示する駅ID

  @override
  _MapScreenState createState() => _MapScreenState(EventNames.SCREEN_MAP);
}

class _MapScreenState extends BaseMapScreenState<MapScreen> {
  _MapScreenState(String eventName) : super(eventName);

  /// マップの開始位置座標 x (左)
  double horizontalStationStart = 0;

  double scaleScreenRatio;

  /// マップの終了位置座標 x (右)
  double horizontalStationEnd = 0;

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addObserver(this);
    // SharedPreferenceUtil.saveScreenName(EventNames.SCREEN_MAP);
    horizontalStationStart = getHorizontalStationStartByLineId(
        SizeConfig.screenHeight, widget.lineStationId[0]);
    horizontalStationEnd = getHorizontalStationEndByLineId(
        SizeConfig.screenHeight, widget.lineStationId[0]);
    metroMapFirstTime++;
    mapScreenisOpened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // await getVottomNavExpanded();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget contentsBuild(BuildContext context) {
    final linesRepository = Provider.of<LinesRepository>(context);
    final lineStationsRepository = Provider.of<LineStationsRepository>(context);
    final trainsRepository = Provider.of<TrainsRepository>(context);
    final appRepository = Provider.of<AppRepository>(context);
    final congestionInfoRepository = Provider.of<CongestionRepository>(context);

    scaleScreenRatio = SizeConfig.scaleScreenRatio;

    return ChangeNotifierProvider(
        create: (context) => _MapBloc(
            widget.lineStationId,
            linesRepository,
            lineStationsRepository,
            trainsRepository,
            appRepository,
            congestionInfoRepository,
            widget.navigatorKey,
            horizontalStationStart),
        child: MapScreenContentWidget(widget.lineStationId, scaleScreenRatio));
  }
}

/// XXX なぜ別 Widget に切り出したのか。切り出しは良いが、他の画面と作り方が変わってしまった。
class MapScreenContentWidget extends BaseStatefulWidget {
  final String lineStationId;
  final double givenScaleScreenRatio;
  const MapScreenContentWidget(this.lineStationId, this.givenScaleScreenRatio,
      {Key key})
      : super(key: key);

  @override
  State<MapScreenContentWidget> createState() => _MapScreenContentWidgetState();
}

class _MapScreenContentWidgetState extends BaseState<MapScreenContentWidget>
    with WidgetsBindingObserver {
  /// navigation(GlobalKey)は一緒
  final NavigationService navigation = sl<NavigationService>();

  /// バックグラウンドになっているかどうか
  bool inBackground = false;

  /// マップの開始位置座標 x (左)
  double horizontalStationStart = 0;
  bool _bottomNavExpanded = false;

  /// マップの終了位置座標 x (右)
  double horizontalStationEnd = 0;
  double scaleScreenRatio;

  final _scrollKey = GlobalKey();

  /// 路線マップブロック
  BaseMapBloc bloc;

  /// 副都心線、有楽町線の特別な他社線への乗り入れ・乗り換え路線
  LineExternalLink siLine;

  /// 都営浅草線からの京急線乗り入れ路線
  LineExternalLink kkLine;

  /// A Network error map
  Map<String, String> networkErrors = {};

  /// 駅情報ダイアログを表示出来たかどうか
  bool trainDialogController;

  /// 駅詳細情報ダイアログを表示出来るかどうか
  bool isShowTrainDialog = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      inBackground = true;
      bloc?.removeNetworkSubscriber();
    }
    if (state == AppLifecycleState.resumed) {
      // Delay 3 seconds for no disconnection notification when returning app from background
      if (inBackground) {
        Future.delayed(const Duration(seconds: 3), () {
          bloc?.addNetworkSubscriber();
        });
      }
      inBackground = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addObserver(this);
    // SharedPreferenceUtil.saveScreenName(EventNames.SCREEN_MAP);
    horizontalStationStart = getHorizontalStationStartByLineId(
        SizeConfig.screenHeight, widget.lineStationId[0]);
    horizontalStationEnd = getHorizontalStationEndByLineId(
        SizeConfig.screenHeight, widget.lineStationId[0]);
    metroMapFirstTime++;
    mapScreenisOpened = true;
    scaleScreenRatio = widget.givenScaleScreenRatio;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<_MapBloc>(context, listen: false).fetchLineData();
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    bloc?.removeAllSubscriber();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<_MapBloc>(
      builder: (context, bloc, _) {
        this.bloc = bloc;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Handle map bloc state
          if (bloc.hasFireStoreError) {
            bloc.hasFireStoreError = false;
            MapFunction()
                .showFireStoreErrorDialog(bloc, context, isShowTrainDialog);
          }
          if (bloc.state == MapState.SUCCESSFULLY) {
            bloc.externalLinksTimer?.cancel();
            bloc.state = MapState.IDLE;
            ExternalLinkLoadingDialog.closeDialog(context);
            await showDialog(
                context: context,
                builder: (context) {
                  return ExternalLineInfoDialog(bloc.stationExternalLinks);
                });
            bloc.externalLinksTimer?.cancel();
          }
          if (bloc.state == MapState.LOADING) {
            bloc.state = MapState.IDLE;
            ExternalLinkLoadingDialog.showExternalLoadingDialog(context);
          }
          if (bloc.state == MapState.ERROR) {
            ExternalLinkLoadingDialog.closeDialog(context);
            bloc.state = MapState.IDLE;
            MapFunction().showErrorDialogForExternalLink(bloc, context);
          }
          if (bloc.state == MapState.TIME_OUT) {
            ExternalLinkLoadingDialog.closeDialog(context);
            bloc.state = MapState.IDLE;
            bloc.externalLinksTimer?.cancel();
            MapFunction().showTimeOutDialog(bloc, context);
          }
          if (bloc.noNetworkError && bloc.state == MapState.NETWORK_ERROR) {
            bloc.state = MapState.IDLE;
            ErrorDialog.showConfirmDialog(
                context: context,
                statusCode: NO_NETWORK_CODE,
                buttonRightAction: () {
                  bloc.checkNetworkAgain();
                },
                buttonLeftAction: () {});
          }
          if (bloc.state == MapState.STATION_MAP_ERROR) {
            bloc.state = MapState.IDLE;
            ErrorDialog.showInfoDialog(
              context: context,
              content: INVALID_INFORMATION,
            );
          }
          if (bloc.netWorkWebViewState) {
            bloc.netWorkWebViewState = false;
            ErrorDialog.showConfirmDialog(
                context: context,
                statusCode: NO_NETWORK_CODE,
                buttonRightAction: () {
                  if (bloc.lastSelectedStation != null) {
                    bloc.getStationMapLink(bloc.lastSelectedStation, context);
                  }
                });
          }
        });
        if (bloc.selectedLine == null) {
          return Container();
        }
        // Check small screen
        final bool isSmallScreen = SizeConfig.isSmallScreen;
        metroMapFirstTime = 0;
        final screenWidth = MediaQuery.of(context).size.width;

        return WillPopScope(
          onWillPop: () async {
            return true;
          },
          child: Column(
            children: [
              Container(
                height: isSmallScreen
                    ? SMALL_SCREEN_HEADER_HEIGHT
                    : BIG_SCREEN_HEADER_HEIGHT,
                child: Stack(
                  children: <Widget>[
                    Column(
                      children: [
                        Container(
                          height: isSmallScreen
                              ? SMALL_SCREEN_STATUS_HEIGHT
                              : BIG_SCREEN_STATUS_HEIGHT,
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned(
                                left: 18.96,
                                child: GestureDetector(
                                  child: MetroImages.backIcon(),
                                  onTap: () {
                                    bloc.goBack();
                                  },
                                ),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: Row(
                                  children: <Widget>[
                                    LineIcon(
                                      lineCode: bloc.selectedLine.id,
                                    ),
                                    Container(
                                      width: 6,
                                    ),
                                    Text(
                                      bloc.selectedLine.name,
                                      style: MetroTextStyles.blackBoldText(18, height: 1.5),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ],
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                ),
                              ),
                              // 列車情報表示設定ダイアログ表示ボタン
                              Positioned(
                                right: 20,
                                child: Visibility(
                                  visible: !bloc.selectedLine.isToei(),
                                  child: GestureDetector(
                                    child: const Icon(
                                      Icons.settings,
                                      size: 24,
                                    ),
                                    onTap: () {
                                      AppTracker.getInstance().screenMapSetting(
                                          bloc.selectedLine,
                                          EventNames.SCREEN_MAP);
                                      showDialog(
                                          context: context,
                                          builder: (context) =>
                                              MapSettingDialog()).then(
                                          (value) => bloc.fetchLineData());
                                    },
                                  ),
                                ),
                              ),
                              // 混雑凡例ダイアログ表示ボタン
                              Positioned(
                                right: 54, // (20:pad + 24:iconw + 10:pad)
                                child: Visibility(
                                  visible: !bloc.selectedLine.isToei(),
                                  child: GestureDetector(
                                    child: Container(
                                      child: MetroImages.congestionRateButton(),
                                      width: 54,
                                      height: 24,
                                    ),
                                    onTap: () {
                                      AppTracker.getInstance()
                                          .actionViewCongestionRateDialog();
                                      showDialog(
                                          context: context,
                                          builder: (context) =>
                                              CongestionRateNoteDialog());
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: isSmallScreen ? 8 : 14.69,
                        )
                      ],
                    ),
                    InkWell(
                      child: Container(
                        width: 80,
                      ),
                      onTap: () {
                        bloc.goBack();
                      },
                    )
                  ],
                ),
              ),
              Container(
                child: Stripe([bloc.selectedLine.color]),
                height: 2,
              ),
              Expanded(
                child: _buildMap(
                    context,
                    bloc.selectedLine,
                    bloc.startExternalLines,
                    bloc.endExternalLines,
                    bloc.stations,
                    bloc.trains,
                    bloc.scrollController,
                    bloc.goToIntersectScreen,
                    bloc.onEndScroll,
                    bloc.showDetails,
                    bloc.visibleMapEndStation,
                    bloc.visibleMapCongestion,
                    bloc.getAllTimetable,
                    bloc.viewTimetable,
                    bloc.stationExternalLinks,
                    bloc.loadExternalLineInfo,
                    bloc.trainsRepository,
                    bloc.fetchLineData,
                    bloc),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 列車部分の構築
  Widget _buildTrain(
      BuildContext context,
      Train train,
      bool showDetails,
      double mapHeight,
      double screenWidth,
      int stackLevel,
      GetTimetable onGetTimetable,
      TrainsRepository trainsRepository,
      void Function() fetchLineData,
      Line selectedLine,
      List<LineStation> lineStations,
      bool visibleMapEndStation,
      bool visibleMapCongestion) {
    if (stackLevel > 3) {
      return Container();
    }
    if (selectedLine.id == 'I') {
      if (train.trainPosition.position.dx <= POSITION_DX_LINE_HIDDEN) {
        return Container();
      }
    }
    var width = 0.0;
    var height = 0.0;
    var x = train.trainPosition.position.dx * DISTANCE_BETWEEN_STATIONS +
        screenWidth / 2 +
        horizontalStationStart;
    var y = mapHeight / 6 * train.trainPosition.position.dy + SPACE_TOP_MAP;
    final trainPosition = train.trainPosition;
    if (trainPosition.direction == Direction.left ||
        trainPosition.direction == Direction.right) {
      // train is drawn horizontally
      // Reduce the ratio when encountering small screens
      width = TRAIN_ICON_LENGTH * scaleScreenRatio;
      height = TRAIN_ICON_WIDTH * scaleScreenRatio;

      // Reduce the distance between  when encountering small screens
      final int trainPositionScale = SizeConfig.distanceVerticalTrain;

      // The train goes to the left
      if (trainPosition.direction == Direction.left) {
        y += DISTANCE_TRAIN_HORIZONTAL_LINE * scaleScreenRatio +
            (stackLevel - 1) * trainPositionScale;
      }
      // The train goes to the right
      else {
        y -= DISTANCE_TRAIN_HORIZONTAL_LINE * scaleScreenRatio +
            (stackLevel - 1) * trainPositionScale;
      }
    }
    // The train goes up and down
    else {
      width = TRAIN_ICON_WIDTH * scaleScreenRatio;
      height = TRAIN_ICON_LENGTH * scaleScreenRatio;
      if (trainPosition.direction == Direction.down) {
        x += DISTANCE_TRAIN_VERTICAL_LINE * scaleScreenRatio +
            (stackLevel - 1) * DISTANCE_BETWEEN_TRAIN;
      } else {
        x -= DISTANCE_TRAIN_VERTICAL_LINE * scaleScreenRatio +
            (stackLevel - 1) * DISTANCE_BETWEEN_TRAIN;
      }
    }

    // Move the train to its central position
    x -= width / 2.0;
    y -= height / 2.0;
    return Positioned(
        left: x,
        top: y,
        child: Container(
          width: width,
          height: height,
          child: GestureDetector(
            child: TrainIcon(
              color: train.line.color,
              delayTime: train.delayTime,
              stopTime: train.stopTime,
              isDisplayStopTime: train.isDisplayStopTime,
              endStation: MapFunction()
                  .getEndStation(train.endStation, train.endStationS),
              direction: train.trainPosition.direction,
              showDetails: true,
              trainCode: train.trainCode,
              apiName: train.line.apiName,
              isScale: true,
              trainNumber: train.id,
              trainFliner: train.trainFliner,
              congestion: train.congestion,
              line: train.line,
              pastStation: train.pastStation,
              visibleMapEndStation: visibleMapEndStation,
              visibleMapCongestion: visibleMapCongestion,
            ),
            onTap: () {
              MapFunction().showTrainDialog(
                  context,
                  onGetTimetable,
                  train,
                  trainsRepository,
                  fetchLineData,
                  lineStations,
                  trainDialogController,
                  isShowTrainDialog);
            },
          ),
        ));
  }

  /// Create map widget メインのマップ部分構築
  /// [selectedLine] current
  /// [startExternalLines], [endExternalLines] list id of external line
  /// [stations]
  Widget _buildMap(
      BuildContext context,
      Line selectedLine,
      List<LineExternalLink> startExternalLines,
      List<LineExternalLink> endExternalLines,
      Map<LineStation, List<LineStation>> stations,
      List<Train> trains,
      ScrollController scrollController,
      OnViewIntersect onViewIntersect,
      void Function(ScrollMetrics) onEndScroll,
      bool showDetails,
      bool visibleMapEndStation,
      bool visibleMapCongestion,
      GetTimetable onGetTimeTable,
      Function(LineStation) viewTimetable,
      List<StationExternalLink> stationExternalLinks,
      loadExternalLineInfo,
      TrainsRepository trainsRepository,
      void Function() fetchLineData,
      _MapBloc bloc) {
    final List<Widget> map = [];
    if (stations == null || stations.isEmpty) {
      return Container();
    }

    final bool isScreenSmall = SizeConfig.isSmallScreen;
    final screenWidth = MediaQuery.of(context).size.width;
    final intersectHeight = INTERSECT_AREA_TOEI_HEIGHT;
    final mapWidth = screenWidth +
        (stations.keys
                .reduce((current, next) => current.x > next.x ? current : next)
                .x) *
            DISTANCE_BETWEEN_STATIONS +
        horizontalStationStart +
        horizontalStationEnd;
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight -
        (isScreenSmall ? SMALL_SCREEN_MAP_HEIGHT : BIG_SCREEN_MAP_HEIGHT) *
            scaleScreenRatio -
        intersectHeight -
        (scaleScreenRatio != 1.0 ? 10 : 0);
    final double stationCircleSize = 32.0 * scaleScreenRatio;

    map.add(
      CustomPaint(
        painter: MapPainter(
          selectedLine,
          stations.keys.toList(),
          screenWidth,
          smallScreenScale: scaleScreenRatio,
          addSpaceToTopMap: true,
          horizontalStationStart: horizontalStationStart,
        ),
        size: Size(mapWidth, mapHeight),
      ),
    );

    int i = 0;
    final List<LineStation> sortedStations = stations.keys.toList();
    sortedStations.sort((a, b) => b.x.compareTo(a.x));
    for (var station in sortedStations) {
      final CongestionInfo congestionInfoDirectionRight = bloc
          .congestionInfoList
          .firstWhere((element) => element.lineStation.id == station.id,
              orElse: () => null);

      CongestionInfo congestionInfoDirectionLeft;
      if (station.nextLineStationId != null) {
        congestionInfoDirectionLeft = bloc.congestionInfoList.firstWhere(
            (element) => element.lineStation.id == station.nextLineStationId,
            orElse: () => null);
      }

      // 混雑状況をマップに配置
      if (i++ != 0 && station.line.sortOrder <= 8) {
        final nextStation = sortedStations.firstWhere(
            (s) => s.id == station.nextLineStationId,
            orElse: () => null);
        map.add(Positioned(
          left: station.x * DISTANCE_BETWEEN_STATIONS +
              screenWidth / 2 +
              horizontalStationStart,
          top: SPACE_TOP_MAP +
              20 +
              (station.line.baseline != station.y ? 25 : 0),
          child: Stack(
            children: <Widget>[
              Container(
                width: nextStation == null
                    ? 0
                    : (nextStation.x - station.x) * DISTANCE_BETWEEN_STATIONS,
                height: 23,
                child: Center(
                  child: Container(
                    height: 23,
                    width: nextStation == null
                        ? 0
                        : (nextStation.x - station.x) *
                                DISTANCE_BETWEEN_STATIONS -
                            13,
                    child: Stack(
                      children: <Widget>[
                        Container(
                          height: 23,
                          child: Center(
                            child: Container(
                              height: 5,
                              width: nextStation == null
                                  ? 0
                                  : (nextStation.x - station.x) *
                                          DISTANCE_BETWEEN_STATIONS -
                                      20,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(1.0),
                                    bottomLeft: Radius.circular(1.0)),
                                color: MetroColors.grayF5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                            right: 0,
                            bottom: 0,
                            top: 0,
                            child: Container(
                                child:
                                    MetroImages.blackF5TriangleRightArrow())),
                      ],
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  await showModalBottomSheet<bool>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) {
                      return CongestionInfoDialog(
                        lineStations: sortedStations,
                        currentLineStation: station,
                        direction: Direction.right,
                        isFromMapScreen: true,
                        congestionInfoList: bloc.congestionInfoList,
                      );
                    },
                  );
                },
                child: Center(
                  child: Container(
                    height: 23,
                    width: DISTANCE_BETWEEN_STATIONS,
                    child: MetroImages.congestionLevelImage(
                      CongestionUtils.getCongestionLevel(
                          congestionInfoDirectionRight,
                          Direction.right,
                          selectedLine.id),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
        map.add(Positioned(
          left: station.x * DISTANCE_BETWEEN_STATIONS +
              screenWidth / 2 +
              horizontalStationStart,
          top: mapHeight - 30 - (station.line.baseline != station.y ? 25 : 0),
          child: Stack(
            children: <Widget>[
              Container(
                width: nextStation == null
                    ? 0
                    : (nextStation.x - station.x) * DISTANCE_BETWEEN_STATIONS,
                height: 23,
                child: Center(
                  child: Container(
                    height: 23,
                    width: nextStation == null
                        ? 0
                        : (nextStation.x - station.x) *
                                DISTANCE_BETWEEN_STATIONS -
                            13,
                    child: Stack(
                      children: <Widget>[
                        Container(
                          height: 23,
                          child: Center(
                            child: Container(
                              height: 5,
                              width: nextStation == null
                                  ? 0
                                  : (nextStation.x - station.x) *
                                          DISTANCE_BETWEEN_STATIONS -
                                      20,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(1.0),
                                    bottomRight: Radius.circular(1.0)),
                                color: MetroColors.grayF5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                            left: 0,
                            bottom: 0,
                            top: 0,
                            child: MetroImages.blackF5TriangleLeftArrow()),
                      ],
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  await showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      elevation: 12.0,
                      anchorPoint: Offset(double.maxFinite, double.maxFinite),
                      // shape: RoundedRectangleBorder(
                      //   borderRadius: BorderRadius.circular(10.0),
                      // ),
                      builder: (context) {
                        return CongestionInfoDialog(
                          lineStations: sortedStations,
                          currentLineStation: station,
                          direction: Direction.left,
                          isFromMapScreen: true,
                          congestionInfoList: bloc.congestionInfoList,
                        );
                      });
                },
                child: Center(
                  child: Container(
                    height: 23,
                    width: DISTANCE_BETWEEN_STATIONS,
                    child: MetroImages.congestionLevelImage(
                      CongestionUtils.getCongestionLevel(
                          congestionInfoDirectionLeft,
                          (nextStation.id == 'M06' && station.id == 'Mb05')
                              ? Direction.down
                              : Direction.left,
                          selectedLine.id),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
      }

      // 駅アイコンをマップに配置
      map.add(Positioned(
          left: station.x * DISTANCE_BETWEEN_STATIONS +
              screenWidth / 2 -
              stationCircleSize / 2 +
              horizontalStationStart,
          top: -stationCircleSize / 2 +
              station.y * mapHeight / 6 +
              SPACE_TOP_MAP,
          child: Container(
            child: GestureDetector(
              child: StationIcon(
                station: station,
                showName: true,
                twoLine: true,
                isScale: true,
              ),
              onTap: () {
                // 駅情報ダイアログ表示
                showLineStationMasterDialog(
                    context,
                    navigation.navigatorKey,
                    bloc.lineStationsRepository,
                    station,
                    EventNames.SCREEN_MAP);
              },
            ),
            width: stationCircleSize,
            height: stationCircleSize,
          )));
      final intersectStations = stations[station];
      intersectStations
          .sort((s1, s2) => s1.line.sortOrder.compareTo(s2.line.sortOrder));

      // のりかえアイコン
      final List<Widget> intersectIcons = [];
      final Widget viewTimeTableIcon = GestureDetector(
        onTap: () {
          viewTimetable(station);
        },
        child: Container(
          width: TIMETABLE_BUTTON_WIDTH,
          height: 22,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: const Color(0xFF263047)),
          child: const Center(
              child: Text(
            TIME_TABLE_BUTTON_TEXT,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 1),
            textAlign: TextAlign.center,
          )),
        ),
      );

      final Widget viewMapStationIcon = GestureDetector(
        onTap: () {
          bloc.goToStationWeb(station, context);
        },
        child: Container(
          width: TIMETABLE_BUTTON_WIDTH,
          height: 22,
          margin: const EdgeInsets.only(top: 4.0),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: const Color(0xFF263047)),
          child: const Center(
              child: Text(
            STATION_MAP_COLUMN_NAME,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 1),
            textAlign: TextAlign.center,
          )),
        ),
      );

      final Widget norikaeText = Container(
        padding: const EdgeInsets.only(top: 4.0, bottom: 0),
        child: const Text(
          TRANSFER_BUTTON_TEXT,
          style: TextStyle(height: 1, fontSize: 11, color: MetroColors.black),
        ),
      );

      /// 乗り換えアイコンの表示
      intersectIcons.addAll(getIntersectStation(
          intersectStations, onViewIntersect, station, loadExternalLineInfo));
      final List<Widget> intersectIconsAfterDivide =
          divideIntersectIcons(intersectIcons);
      map.add(Positioned(
        left: station.x * DISTANCE_BETWEEN_STATIONS +
            screenWidth / 2 -
            TIMETABLE_BUTTON_WIDTH / 2 +
            horizontalStationStart,
        top: mapHeight,
        child: Column(
          children: <Widget>[
            viewTimeTableIcon,
            viewMapStationIcon,
            intersectIcons.isNotEmpty ? norikaeText : Container(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: intersectIconsAfterDivide,
            ),
          ],
        ),
      ));
    }

    // 列車状況をマップに配置
    bool isShowTrain = true;
    if (selectedLine.isToei()) {
      if (bloc.toeiTrainPositionError) {
        isShowTrain = false;
      }
    } else {
      if (bloc.hitachiTrainPositionError) {
        isShowTrain = false;
      }
    }
    if (bloc.noNetworkError) {
      isShowTrain = false;
    }

    final Map<Offset, Map<Direction, List<Train>>> trainMap = {};
    if (trains != null && isShowTrain) {
      for (int i = 0; i < trains.length; ++i) {
        final train = trains[i];
        if (train.trainPosition == null) {
          continue;
        }

        final offset = train.trainPosition.position;
        final direction = train.trainPosition.direction;

        if (!trainMap.containsKey(offset)) {
          trainMap[offset] = {};
        }
        if (trainMap[offset][direction] == null) {
          trainMap[offset][direction] = <Train>[];
        }
        trainMap[offset][direction].add(train);
      }

      // 列車の配置（右方向）
      // Sort train list by dx of offset
      // The rear train is on the front train with right direction
      final offsets = trainMap.keys.toList();
      offsets.sort((offset1, offset2) => offset2.dx.compareTo(offset1.dx));
      for (var offset in offsets) {
        for (var direction in trainMap[offset].keys) {
          if (direction == Direction.left) {
            continue;
          }
          int stackLevel = 0;
          trainMap[offset][direction].sort((t1, t2) => t1
              .trainPosition.positionNumber
              .compareTo(t2.trainPosition.positionNumber));
          for (var train in trainMap[offset][direction]) {
            final trainDirection =
                StringUtils.mapTrainDirectionToPositionDirection(
                    selectedLine.id, train.direction);
            if (trainDirection == Direction.right) {
              map.add(_buildTrain(
                  context,
                  train,
                  showDetails,
                  mapHeight,
                  screenWidth,
                  ++stackLevel,
                  onGetTimeTable,
                  trainsRepository,
                  fetchLineData,
                  selectedLine,
                  bloc.stations.keys.toList(),
                  visibleMapEndStation,
                  visibleMapCongestion));
            }
          }
        }
      }

      // 列車の配置（左方向）
      // Sort train list by dx of offset
      // The rear train is on the front train with left direction
      final offsets2 = trainMap.keys.toList();
      offsets2.sort((offset1, offset2) => offset1.dx.compareTo(offset2.dx));
      for (var offset in offsets2) {
        for (var direction in trainMap[offset].keys) {
          if (direction == Direction.right) {
            continue;
          }
          int stackLevel = 0;
          trainMap[offset][direction].sort((t1, t2) => t1
              .trainPosition.positionNumber
              .compareTo(t2.trainPosition.positionNumber));
          for (var train in trainMap[offset][direction]) {
            final trainDirection =
                StringUtils.mapTrainDirectionToPositionDirection(
                    selectedLine.id, train.direction);
            if (trainDirection == Direction.left) {
              map.add(_buildTrain(
                  context,
                  train,
                  showDetails,
                  mapHeight,
                  screenWidth,
                  ++stackLevel,
                  onGetTimeTable,
                  trainsRepository,
                  fetchLineData,
                  selectedLine,
                  bloc.stations.keys.toList(),
                  visibleMapEndStation,
                  visibleMapCongestion));
            }
          }
        }
      }
    }

    // 他社線乗り入れの表示(左)
    // Show special external company (ex: line A) => do not show start external Line icon
    if (startExternalLines != null) {
      final List<LineExternalLink> cacheExternalList = [...startExternalLines];
      if (selectedLine.id == 'F' || selectedLine.id == 'Y') {
        cacheExternalList
            .sort((s1, s2) => s2.externalLineId.compareTo(s1.externalLineId));
        siLine = startExternalLines.firstWhere(
            (element) => element.externalLineId.contains('SI'),
            orElse: () => null);
        cacheExternalList
            .removeWhere((element) => element.externalLineId.contains('SI'));
        if (siLine != null) {
          // 西武池袋線の乗り入れ表示
          map.add(
            Positioned(
              left: 5,
              top: (mapHeight / 6) * 4.3 + SPACE_TOP_MAP,
              child: Container(
                width: 24,
                child: Center(
                  child: MediaQuery.removePadding(
                    removeTop: true,
                    context: context,
                    child: ListView.builder(
                      itemCount: 1,
                      itemBuilder: (context, index) {
                        // return MetroImages.verticalExternalLine(siLine.externalLineId);
                        final externalIcon = GestureDetector(
                          onTap: () {
                            MapFunction().onExternalLineTap(
                                siLine.externalLineId,
                                EventNames.SCREEN_MAP,
                                false,
                                bloc,
                                context);
                          },
                          child: MetroImages.verticalExternalLine(
                              siLine.externalLineId),
                        );
                        return externalIcon;
                      },
                      shrinkWrap: true,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        drawSITextInLineFY(
            selectedLine, map, mapHeight, screenWidth); // 乗り換え・乗り入れ路線テキスト表示
      } else if (selectedLine.id == 'A') {
        cacheExternalList
            .sort((s1, s2) => s2.externalLineId.compareTo(s1.externalLineId));
        kkLine = startExternalLines.firstWhere(
            (element) => element.externalLineId.contains('KK'),
            orElse: () => null);
        cacheExternalList
            .removeWhere((element) => element.externalLineId.contains('KK'));
        if (kkLine != null) {
          final double topPosition = (mapHeight / 6) * (4 - 0.1);
          map.add(
            Positioned(
              left: 5,
              top: topPosition,
              child: Container(
                width: 24,
                child: Center(
                  child: MediaQuery.removePadding(
                    removeTop: true,
                    context: context,
                    child: ListView.builder(
                      itemCount: 1,
                      itemBuilder: (context, index) {
                        // return MetroImages.verticalExternalLine(siLine.externalLineId);
                        final externalIcon = GestureDetector(
                          onTap: () {
                            MapFunction().onExternalLineTap(
                                kkLine.externalLineId,
                                EventNames.SCREEN_MAP,
                                false,
                                bloc,
                                context);
                          },
                          child: MetroImages.verticalExternalLine(
                              kkLine.externalLineId),
                        );
                        return externalIcon;
                      },
                      shrinkWrap: true,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        drawKKTextInLineA(
            selectedLine, map, mapHeight, screenWidth); // 乗り換え・乗り入れ路線テキスト表示
      }

      // logDebug('baseline: ${selectedLine.baseline}, scaleScreenRatio: $scaleScreenRatio, map-height: $mapHeight');

      /// 枝ではない、通常の左端の乗り入れ表示
      /// baseline 1: (今は存在しない) 2:やや上(千代田線,都営浅草線) 3: 中央1線(殆どの路線)
      map.add(
        Positioned(
          left: 5,
          top: 0 +
              SPACE_TOP_MAP +
              10 +
              (selectedLine.baseline == 3 ? mapHeight / 3 : mapHeight / 5),
          // top: 0 + SPACE_TOP_MAP + 10,
          // bottom: 200 * scaleScreenRatio + (selectedLine.baseline == 3 ? 0.0 : mapHeight / 3),
          child: Container(
            width: 24,
            child: Center(
              child: MediaQuery.removePadding(
                removeTop: true,
                context: context,
                child: ListView.builder(
                  itemCount: cacheExternalList.length,
                  itemBuilder: (context, index) {
                    // return MetroImages.verticalExternalLine(cacheExternalList[index].externalLineId);
                    final externalIcon = GestureDetector(
                      onTap: () {
                        MapFunction().onExternalLineTap(
                            cacheExternalList[index].externalLineId,
                            EventNames.SCREEN_MAP,
                            false,
                            bloc,
                            context);
                      },
                      child: MetroImages.verticalExternalLine(
                          cacheExternalList[index].externalLineId),
                    );
                    return externalIcon;
                  },
                  shrinkWrap: true,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 他社線乗り入れの表示(右)
    if (endExternalLines != null) {
      map.add(
        Positioned(
          right: 5,
          top: 0 +
              SPACE_TOP_MAP +
              10 +
              (selectedLine.baseline == 3 ? mapHeight / 3 : mapHeight / 5) -
              ((endExternalLines?.length ?? 0) > 1 ? 25 : 0),
          // top: 0 + SPACE_TOP_MAP + 10,
          // bottom: 200 * scaleScreenRatio +
          //     (selectedLine.baseline == 3 ? 0.0 : mapHeight / 3) -
          //     ((endExternalLines?.length ?? 0) > 1 ? 25 : 0),
          child: Container(
            width: 24,
            child: Center(
              child: MediaQuery.removePadding(
                removeTop: true,
                context: context,
                child: ListView.builder(
                  itemCount: endExternalLines.length,
                  padding: EdgeInsets.only(
                      top: (endExternalLines?.length ?? 0) > 1 ? 20 : 0),
                  itemBuilder: (context, index) {
                    // return MetroImages.verticalExternalLine(endExternalLines[index]);
                    final externalIcon = GestureDetector(
                      onTap: () {
                        MapFunction().onExternalLineTap(
                            endExternalLines[index].externalLineId,
                            EventNames.SCREEN_MAP,
                            true,
                            bloc,
                            context);
                      },
                      child: MetroImages.verticalExternalLine(
                          endExternalLines[index].externalLineId),
                    );
                    return externalIcon;
                  },
                  shrinkWrap: true,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Draw warning text in line I
    drawWarningTextInLineI(selectedLine, map, mapHeight, screenWidth);
    // check small screen
    final bool isSmallScreen = SizeConfig.isSmallScreen;
    MyLogger.d("##Helo $_bottomNavExpanded");
    // if (bloc.scrollPostion != 0.0) {
    //   bloc.scrollToValue();
    // }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            if (scrollNotification is ScrollEndNotification) {
              onEndScroll(scrollNotification.metrics);
            }
            return true;
          },
          child: ScrollConfiguration(
            behavior: IOSScrollBehavior(),
            child: SingleChildScrollView(
              key: _scrollKey,
              physics: AlwaysScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              child: Container(
                child: Stack(
                  children: map,
                ),
                width: mapWidth - DISTANCE_BETWEEN_STATIONS / 2,
              ),
              controller: scrollController,
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: isSmallScreen ? 5 : 12,
          child: Row(
            children: [
              MetroImages.rewindIcon(),
              Text(
                ' ${stations.keys.reduce((current, next) => current.x < next.x ? current : next).station.name}方面',
                style: MetroTextStyles.grey44BoldText(12),
              )
            ],
          ),
        ),
        Positioned(
          right: 10,
          top: isSmallScreen ? 5 : 12,
          child: Row(
            children: [
              Text(
                '${stations.keys.reduce((current, next) => current.x > next.x ? current : next).station.name}方面 ',
                style: MetroTextStyles.grey44BoldText(12),
              ),
              MetroImages.forwardIcon()
            ],
          ),
        ),
        Positioned(
            bottom: 25,
            child: Container(
                width: screenWidth,
                alignment: Alignment.center,
                child: TrainPositionMessage(
                  // API取得メッセージ（更新日時＋注意書き or エラーメッセージ）
                  selectedLine: bloc.selectedLine,
                  hitachiTrainPositionError: bloc.hitachiTrainPositionError,
                  toeiTrainPositionError: bloc.toeiTrainPositionError,
                  hitachiTrainPosCode: bloc.hitachiTrainPosCode,
                  toeiTrainPosCode: bloc.toeiTrainPosCode,
                  updatedTimes: bloc.updatedTimes,
                  trains: bloc.trains,
                ))),
      ],
    );
  }

  /// Warning text show in station I1, I2
  void drawWarningTextInLineI(Line selectedLine, List<Widget> map,
      double mapHeight, double screenWidth) {
    if (selectedLine.id == 'I') {
      const arcWidth = MapPainter.ARC_WIDTH;
      map.add(Positioned(
        top: mapHeight / 6 * 2 - arcWidth + SPACE_TOP_MAP,
        left: -1 * DISTANCE_BETWEEN_STATIONS +
            screenWidth / 2 +
            horizontalStationStart -
            10,
        child: Row(
          children: <Widget>[
            Text(
              WARNING_LINE_I_PART_I,
              style: TextStyle(
                fontSize: 11 * scaleScreenRatio,
                fontWeight: FontWeight.w400,
                color: MetroColors.black,
              ),
            ),
            InkWell(
              onTap: () {
                bloc.changeLine('N01');
              },
              child: Text(
                WARNING_LINE_I_PART_II,
                style: TextStyle(
                    fontSize: 11 * scaleScreenRatio,
                    fontWeight: FontWeight.w400,
                    color: MetroColors.black,
                    decoration: TextDecoration.underline),
              ),
            ),
            Text(
              WARNING_LINE_I_PART_III,
              style: TextStyle(
                fontSize: 11 * scaleScreenRatio,
                fontWeight: FontWeight.w400,
                color: MetroColors.black,
              ),
            ),
          ],
        ),
      ));
    }
  }

  /// 副都心線、有楽町線のテキスト表示
  void drawSITextInLineFY(Line selectedLine, List<Widget> map, double mapHeight,
      double screenWidth) {
    if (selectedLine.id == 'F' || selectedLine.id == 'Y') {
      const arcWidth = MapPainter.ARC_WIDTH;
      map.add(Positioned(
          left: 3 * DISTANCE_BETWEEN_STATIONS +
              screenWidth / 2 +
              horizontalStationStart +
              (DISTANCE_BETWEEN_STATIONS - (DISTANCE_BETWEEN_STATIONS - 13)) *
                  0.5,
          top: mapHeight / 6 * 5 - arcWidth + SPACE_TOP_MAP + 35,
          child: GestureDetector(
            onTap: () {
              MapFunction().onExternalLineTap(siLine.externalLineId,
                  EventNames.SCREEN_MAP, false, bloc, context);
            },
            child: MetroImages.SIHorizontalSmallText(
                height: 14 * scaleScreenRatio),
          )));
    }
  }

  /// 都営浅草線：京急線乗り入れのテキスト表示
  void drawKKTextInLineA(Line selectedLine, List<Widget> map, double mapHeight,
      double screenWidth) {
    if (selectedLine.id == 'A') {
      const arcWidth = MapPainter.ARC_WIDTH;
      map.add(Positioned(
          left: 4 * DISTANCE_BETWEEN_STATIONS +
              screenWidth / 2 +
              horizontalStationStart +
              (DISTANCE_BETWEEN_STATIONS - (DISTANCE_BETWEEN_STATIONS - 62)) *
                  0.5,
          top: mapHeight / 6 * 4 - arcWidth + SPACE_TOP_MAP + 35,
          child: GestureDetector(
            onTap: () {
              MapFunction().onExternalLineTap(kkLine.externalLineId,
                  EventNames.SCREEN_MAP, false, bloc, context);
            },
            // child: MetroImages.KKHorizontalSmallText(height: 15 * scaleScreenRatio),
            child: const Text(
              KEIKYU_LINE_NAME,
              style:
                  TextStyle(height: 1, fontSize: 11, color: MetroColors.black),
            ),
          )));
    }
  }

  /// 乗り換えアイコン
  /// Show intersect icon in the bottom of screen
  /// [intersectStations] list of intersect station
  /// Function [onViewIntersect] go to intersect screen
  /// [station] selected station
  /// Function [loadExternalLineInfo] show external line dialog
  List<Widget> getIntersectStation(
      List<LineStation> intersectStations,
      OnViewIntersect onViewIntersect,
      LineStation station,
      loadExternalLineInfo) {
    final List<Widget> intersectIcons = [];
    for (LineStation intersectStation in intersectStations) {
      if (intersectStation == null) {
        continue;
      }
      intersectIcons.add(Container(
        height: 6,
      ));

      // Check train info error
      bool hasTrainInfoError = false;
      if (intersectStation.line.isToei()) {
        if (bloc.toeiTrainInfoError) {
          hasTrainInfoError = true;
        }
      } else {
        if (bloc.hitachiTrainInfoError) {
          hasTrainInfoError = true;
        }
      }

      final Line line = bloc.lines.firstWhere(
          (line) => line.id == intersectStation.line.id,
          orElse: () => null);
      if (line == null ||
          line.lineStatus == LineStatus.normal ||
          line.lineStatus == LineStatus.other ||
          line.lineStatus == LineStatus.overtime ||
          line.lineStatus == LineStatus.toeiDelay ||
          hasTrainInfoError) {
        intersectIcons.add(Container(
          clipBehavior: Clip.none,
          width: 26 * scaleScreenRatio,
          height: 26 * scaleScreenRatio,
          child: InkWell(
            onTap: () {
              onViewIntersect(station, intersectStation);
            },
            child: LineIcon(
              lineCode: intersectStation.line.id,
            ),
          ),
        ));
      } else {
        intersectIcons.add(Container(
          width: 26 * scaleScreenRatio,
          height: 26 * scaleScreenRatio,
          child: InkWell(
            onTap: () {
              onViewIntersect(station, intersectStation);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 26 * scaleScreenRatio,
                  height: 26 * scaleScreenRatio,
                  child: LineIcon(
                    lineCode: intersectStation.line.id,
                  ),
                ),
                Positioned(
                  child: MetroImages.lineIndicator(),
                  top: -2,
                  right: -2,
                )
              ],
            ),
          ),
        ));
      }
    }
    if (station.hasExternalLink) {
      // 乗り換えアイコン：他社線
      final externalIcon = GestureDetector(
        onTap: () {
          AppTracker.getInstance().actionShowExternalLine();
          loadExternalLineInfo(station.id);
        },
        child: SvgPicture.asset(
          'assets/icons/train_intersect_icon.svg',
          width: 24 * scaleScreenRatio,
          height: 24 * scaleScreenRatio,
        ),
      );
      intersectIcons.add(Container(height: 6));
      intersectIcons.add(externalIcon);
    }
    return intersectIcons;
  }

  /// Show 3 row icon
  /// return list contains sub-lists with 3 or fewer icons
  List<Widget> divideIntersectIcons(List<Widget> intersectIcons) {
    final List<Widget> IntersectIconDivided = [];

    // Each intersect icon has a space on the head => divide by 6
    final int numColumn = (intersectIcons.length / 6).ceil();
    int start = 0;
    int end = 0;

    // Divide the list into sub lists with 3 or fewer icons
    List<Widget> subList;
    for (int i = 0; i < numColumn; i++) {
      start = i * 6;
      end =
          start + 6 > intersectIcons.length ? intersectIcons.length : start + 6;
      subList = intersectIcons.sublist(start, end);

      // Add spaces between columns
      if (i > 0) {
        IntersectIconDivided.add(Container(width: 8.0));
      }
      IntersectIconDivided.add(Column(
        children: subList,
      ));
    }
    return IntersectIconDivided;
  }
}

/// ============================================================================
/// 路線マップ本体ブロック
/// 変更通知により、構築しなおすブロック
class _MapBloc extends BaseMapBloc {
  _MapBloc(
      this._middleLineStationId,
      linesRepository,
      lineStationsRepository,
      trainsRepository,
      appRepository,
      congestionRepository,
      navigatorKey,
      horizontalStationStart)
      : super(
            _middleLineStationId,
            linesRepository,
            lineStationsRepository,
            trainsRepository,
            appRepository,
            congestionRepository,
            horizontalStationStart) {
    // scrollController = ScrollController();
    // externalRepository = ExternalLineRepositoryImpl(lineStationsRepository, linesRepository);
  }

  /// Remove all Subscriber when this screen is dispose
  /// Don't call bloc's dispose() function in map screen, because there are too many async function.
  /// When we dispose this bloc class, It throws an exception related to the notifyListeners() function.
  @override
  void removeAllSubscriber() {
    super.removeAllSubscriber();
    _lineSubscription?.cancel();
  }

  int _appOpenCount = 0;

  void setAppOpenCount() {
    _appOpenCount++;

    MyLogger.d("###setScrollPosition: $_appOpenCount");
  }

  /// Line station in the middle of screen
  /// 中央に表示する駅ID
  final String _middleLineStationId;

  /// A start space of map
  // double horizontalStationStart;

  /// 路線の監視
  StreamSubscription<List<Line>> _lineSubscription;

  /// 乗り換え画面（２路線表示）へ遷移
  Future goToIntersectScreen(
      LineStation horizontalStation, LineStation verticalStation) async {
    removeNetworkSubscriber();
    removeFireStoreSubscriber();
    navigation
        .navigateToIntersect(
            horizontalStation, verticalStation, EventNames.SCREEN_MAP)
        .then((lineStation) {
      addFireStoreSubscriber();
      addNetworkSubscriber();
      handleUIWithFirebaseError();
      trainsRepository.listenToLine(selectedLine.apiName);
      trackingMapScreen(
          fromScreen: EventNames.SCREEN_INTERSECT,
          lineStationID: _middleLineStationId);
      MyLogger.d('intersectBack.lineStation: $lineStation');
      if (lineStation != null &&
          lineStation.toString().startsWith('lineStation:')) {
        changeLine('N01');
      }
      SharedPreferenceUtil.saveScreenName(EventNames.SCREEN_MAP);
    });
  }

  /// 路線のデータを読み込む
  /// 非同期実行され、それぞれ読み込み完了した際に notify する
  @override
  void fetchLineData() {
    /// 路線情報監視の再設定
    _lineSubscription?.cancel();
    _lineSubscription = linesRepository.watchAllLines().listen((data) {
      lines = data;
      notifyListeners();
    });

    /// 中央に表示する駅の設定
    final middleLineStation =
        lineStationsRepository.getById(_middleLineStationId);

    selectedLine = middleLineStation.line; // メイン路線の設定

    /// 路線の各駅情報の取得
    fetchLineStations();

    /// 画面のサイズから、スクロール範囲を設定
    scrollController = ScrollController(
        initialScrollOffset: middleLineStation.x * DISTANCE_BETWEEN_STATIONS +
            (middleLineStation.x < 0
                ? -horizontalStationStart
                : horizontalStationStart));

    super.fetchLineData();

    /// 混雑状況の取得
    fetchCongestionData();

    notifyListeners();
  }

  void scrollMap(double position) {
    /// 中央に表示する駅の設定

    scrollController = ScrollController(initialScrollOffset: position);
  }
}
