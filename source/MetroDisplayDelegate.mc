import Toybox.Lang;
import Toybox.WatchUi;

//! MetroDisplayDelegate
//! Handles user interaction events on the watch face (touchscreen press/tap)
//! to toggle simulated sunlight states in the simulator and on device.
class MetroDisplayDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as MetroDisplayView;

    function initialize(view as MetroDisplayView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! Handle touch press on watch face screen
    function onPress(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        _view.toggleDebugSunlight();
        return true;
    }

}
