import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:metro_app/app/app_constant.dart';
import 'package:metro_app/common/const.dart';
import 'package:metro_app/di_container.dart';
import 'package:metro_app/entities/line.dart';
import 'package:metro_app/repositories/lines_repository.dart';
import 'package:metro_app/services/app_tracker.dart';
import 'package:metro_app/services/event_name.dart';
import 'package:metro_app/services/navigation_service.dart';
import 'package:metro_app/utils/method_utils.dart';
import 'package:metro_app/views/base/base_bloc.dart';
import 'package:metro_app/views/base/screens/base_app_screen.dart';
import 'package:metro_app/widgets/atomic/atoms/line_icon.dart';
import 'package:metro_app/widgets/atomic/organisms/error_dialog.dart';
import 'package:metro_app/widgets/header_line_color.dart';
import 'package:metro_app/widgets/styles/metro_colors.dart';
import 'package:metro_app/widgets/styles/metro_images.dart';
import 'package:metro_app/widgets/styles/metro_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum LineListState { IDLE, LOADING, COMPLETE }

/// 遅延証明書
/// 路線リスト
/// TODO 混雑状況・改札口、のりかえ出口案内など、路線一覧の遷移は色々とあるので共通化したい
/// XXX 路線を選択した際と、詳細画面の WebView が一緒にこのソースファイルに記述されている（ちょっとわかりにくい）
class LineListScreen extends BaseAppScreen {
  const LineListScreen(GlobalKey<NavigatorState> navigatorKey,
      {String shortCutMode, bool displayAdvertisedBanner, Key key})
      : super(navigatorKey, shortCutMode: shortCutMode, displayAdvertisedBanner: displayAdvertisedBanner);

  @override
  _LineListScreenState createState() =>
      _LineListScreenState(EventNames.SCREEN_LINE_LIST);
}

class _LineListScreenState extends BaseAppScreenState<LineListScreen> {
  _LineListScreenState(String eventName) : super(eventName);

  // Line _selectedLine;

  @override
  Widget contentsBuild(BuildContext context) {
    final linesRepository = Provider.of<LinesRepository>(context);

    return ChangeNotifierProvider<_LineListBloc>(
        create: (context) => _LineListBloc(linesRepository),
        child: LineListScreenContent(
          shortCutMode: widget.shortCutMode,
        ));
  }
}

class LineListScreenContent extends StatefulWidget {
  final String shortCutMode;
  const LineListScreenContent({Key key, @required this.shortCutMode})
      : super(key: key);

  @override
  State<LineListScreenContent> createState() => _LineListScreenContentState();
}

class _LineListScreenContentState extends State<LineListScreenContent> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      Provider.of<_LineListBloc>(context, listen: false).fetchAllLines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<_LineListBloc>(
      builder: (context, bloc, _) {
        //_selectedLine = bloc.selectedLine;
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          if (bloc.hasNetworkError) {
            ErrorDialog.showConfirmDialog(
                context: context,
                title: NO_INTERNET_TITLE,
                content: NO_INTERNET_CONTENT,
                statusCode: NO_NETWORK_CODE,
                buttonRightAction: () {
                  if (bloc._selectedLineCache != null) {
                    bloc.goToLineDetails(bloc._selectedLineCache);
                  }
                });
            bloc.hasNetworkError = false;
          }
        });

        final lines = bloc.lines;
        if (lines == null || lines.isEmpty) {
          return Container();
        }
        List<Widget> content = [];

        if (bloc.selectedLine == null) {
          final List<Widget> lineWidgets = [];
          lineWidgets.add(_getTitleList(TOKYO_METRO_NAME));
          lineWidgets.add(const Divider(height: 1));
          for (var line in lines) {
            if (line.sortOrder > 8) {
              continue;
            }
            lineWidgets.add(GestureDetector(
              behavior: HitTestBehavior.translucent,
              child: Container(
                height: 37,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                    ),
                    Container(
                      child: LineIcon(
                        lineCode: line.id,
                      ),
                      width: 37,
                      height: 37,
                    ),
                    Container(
                      width: 13,
                    ),
                    Text(
                      line.name,
                      style: MetroTextStyles.blackBoldText(16),
                      textAlign: TextAlign.left,
                    ),
                    Expanded(
                      child: Container(),
                    ),
                    MetroImages.arrowIcon(),
                    Container(
                      width: 19.65,
                    )
                  ],
                ),
              ),
              onTap: () {
                bloc.goToLineDetails(line);
              },
            ));
            lineWidgets.add(const Divider(
              height: 1,
              thickness: 1,
            ));
          }

          ///Add toei link
          lineWidgets.add(_getTitleList(TOEI_NAME));
          lineWidgets.add(const Divider(
            height: 1,
          ));
          lineWidgets.add(_getToeiItem(bloc, lines[9]));
          lineWidgets.add(const Divider(height: 1));
          lineWidgets.add(const SizedBox(height: 30));

          content = [
            Container(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    CAN_CHECK_DELAY_CERTIFICATE,
                    style: MetroTextStyles.grey22NormalText(12),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
              height: 30,
              margin: const EdgeInsets.only(left: 20),
            ),
            const Divider(
              height: 1.0,
              thickness: 1,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: lineWidgets,
                ),
              ),
            )
          ];
        } else {
          content = [
            _getBody(bloc),
          ];
        }
        return WillPopScope(
          onWillPop: () {
            bloc.goBack();
            return Future.value(false);
          },
          child: Column(
            children: [
              HeaderLineColor(
                lineColors: bloc.selectedLine == null
                    ? headerLineColor
                    : [bloc.selectedLine.color],
                title: PROOF_OF_DELAY,
                canBack: bloc.canBack,
                onBack: bloc.goBack,
                withRightSettingButton: bloc.withRightSettingButton,
                settingTargetNavigatorKey: bloc.withRightSettingButton
                    ? NavigationService.NAVIGATOR_KEY_LINES
                    : '',
                backButtonVisible:
                    widget.shortCutMode != 'shortcut_tab_fixed' ? true : false,
              ),
            ]..addAll(content),
            crossAxisAlignment: CrossAxisAlignment.stretch,
          ),
        );
      },
    );
  }

  Widget _getTitleList(String title) {
    return Container(
      height: 37,
      color: MetroColors.greyf6,
      padding: const EdgeInsets.only(left: 20.0),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: MetroTextStyles.blackNormalText(13),
          ),
        ],
      ),
    );
  }

  Widget _getBody(_LineListBloc bloc) {
    return Expanded(
      child: Container(
        child: Stack(
          children: <Widget>[
            WebView(
              initialUrl: bloc.detailsUrl,
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (s) {
                bloc.setShowLoading();
                bloc.webViewController = s;
              },
              onPageFinished: (s) {
                bloc.setIdleState();
                bloc.webViewController?.evaluateJavascript(
                    "document.documentElement.style.webkitUserSelect='none'");
                bloc.webViewController?.evaluateJavascript(
                    "document.documentElement.style.webkitTouchCallout='none'");
              },
            ),
            Visibility(
              visible: bloc.state == LineListState.LOADING,
              child: Center(
                child: Container(
                  height: 50,
                  width: 50,
                  child: MetroImages.loadingIcon(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getToeiItem(_LineListBloc bloc, Line line) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: 37,
        margin: const EdgeInsets.only(top: 12, bottom: 12),
        child: Row(
          children: [
            Container(
              width: 20,
            ),
            Container(
              child: MetroImages.toeiLogo(),
              width: 29,
              height: 29,
            ),
            Container(
              width: 13,
            ),
            Text(
              TOEI_NAME,
              style: MetroTextStyles.blackBoldText(16),
              textAlign: TextAlign.left,
            ),
            Expanded(
              child: Container(),
            ),
            MetroImages.arrowIcon(),
            Container(
              width: 19.65,
            )
          ],
        ),
      ),
      onTap: () {
        bloc._trackingDelayCertificationScreen(isToei: true);
        launchUrlFun(AppConstant.TOEI_DETAILLS_URL);
      },
    );
  }
}

/// 路線を選択しているかどうかで、状態を管理している
/// TODO 別画面に分けたい
class _LineListBloc extends BaseBloc {
  _LineListBloc(
    this._linesRepository,
  );

  /// Flag to check network state
  bool hasNetworkError = false;

  bool withRightSettingButton = true;

  final LinesRepository _linesRepository;

  /// List of lines
  List<Line> _lines;
  Line _selectedLine;
  Line _selectedLineCache;
  var state = LineListState.IDLE;

  List<Line> get lines => _lines;

  Line get selectedLine => _selectedLine;

  WebViewController webViewController;

  String get detailsUrl {
    if (_selectedLine.sortOrder > 8) {
      return AppConstant.TOEI_DETAILLS_URL;
    }
    return AppConstant.DETAILS_URL
        .replaceAll('\$lineName', _selectedLine.apiName);
  }

  void fetchAllLines() {
    _linesRepository.getAllLines().then((result) {
      _lines = result;

      notifyListeners();
    }, onError: (e) {
      logDebug('fetchAllLines() Error:', obj: e);
    });
  }

  Future goToLineDetails(Line line) async {
    final netWorkStatus = await sl<Connectivity>().checkConnectivity();
    if (netWorkStatus == ConnectivityResult.none) {
      // no net work
      _selectedLineCache = line;
      hasNetworkError = true;
      notifyListeners();
    } else {
      _trackingDelayCertificationScreen(line: line);
      _selectedLine = line;
      withRightSettingButton = false;
      notifyListeners();
    }
  }

  void _trackingDelayCertificationScreen({Line line, bool isToei = false}) {
    final eventParams = <String, dynamic>{};
    eventParams['line'] = isToei ? 'toei' : '${line.apiName}';
    AppTracker.getInstance().screenDelayCertification(parameters: eventParams);
  }

  @override
  void goBack() {
    if (_selectedLine != null) {
      _selectedLine = null;
      withRightSettingButton = true;
      notifyListeners();
    } else {
      navigation.goBack();
    }
  }

  /// 戻れるかどうか
  /// 路線選択時は、元に戻れる
  @override
  bool canBack() {
    if (_selectedLine != null) {
      return true;
    }
    return super.canBack();
  }

  void setShowLoading() {
    state = LineListState.LOADING;
    notifyListeners();
  }

  void setIdleState() {
    state = LineListState.IDLE;
    notifyListeners();
  }
}
