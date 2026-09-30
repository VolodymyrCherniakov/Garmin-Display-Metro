import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class MetroDisplayApp extends Application.AppBase {

    private var _view as MetroDisplayView?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new MetroDisplayView();
        _view = view;
        if (WatchUi has :WatchFaceDelegate) {
            return [ view, new MetroDisplayDelegate(view) ];
        }
        return [ view ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.onSettingsChanged();
        }
        WatchUi.requestUpdate();
    }

}

function getApp() as MetroDisplayApp {
    return Application.getApp() as MetroDisplayApp;
}