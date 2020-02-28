import Foundation

import BanubaSdk
import BanubaEffectPlayer

class TestHandler
{
    class func setupTesting(sdkManager: BanubaSdkManager, view: ViewController)
    {
        if (CommandLine.arguments.count != 2) {
            return
        }
        
        print(CommandLine.arguments[1])
        
        class TestEventHandler: BNBEffectEventListener
        {
            weak var view: ViewController?;
            func onEffectEvent(_ name:String, params: Dictionary<String, String>)
            {
                if (name == "autotest_result") {
                    print("autotest_result " + params["result"]!)
                } else if (name == "autotest_take_photo_please") {
                    print(name)
                    view!.takeFakePhoto()
                } else {
                    print(name)
                    print(params)
                }
            }
        }
        let h = TestEventHandler();
        h.view = view;
        sdkManager.effectPlayer?.add(h);
        
        sdkManager.effectPlayer?.callJsMethod("autotest_config", params: CommandLine.arguments[1])
    }
}
