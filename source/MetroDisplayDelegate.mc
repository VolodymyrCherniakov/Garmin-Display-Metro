import Toybox.Lang;
import Toybox.WatchUi;

//! MetroDisplayDelegate
//! Handles touch-and-hold events to toggle explicitly selected lamp simulations.
//! Automatic mode always follows the solar sensor and ignores this gesture.
class MetroDisplayDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as MetroDisplayView;

    function initialize(view as MetroDisplayView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! Handle touch and hold on the watch face screen
    function onPress(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        _view.toggleDebugSunlight();
        return true;
    }

}
