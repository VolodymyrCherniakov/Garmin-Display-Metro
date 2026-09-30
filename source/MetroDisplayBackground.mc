import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class Background extends WatchUi.Drawable {

    function initialize() {
        var dictionary = {
            :identifier => "Background"
        };

        Drawable.initialize(dictionary);
    }

    function draw(dc as Graphics.Dc) as Void {
        var bgColor = Graphics.COLOR_BLACK;
        try {
            if (Application has :Properties && Application.Properties has :getValue) {
                var val = Application.Properties.getValue("BackgroundColor");
                if (val != null) {
                    bgColor = val as Lang.Number;
                }
            }
        } catch (e) {
            bgColor = Graphics.COLOR_BLACK;
        }
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();
    }

}
