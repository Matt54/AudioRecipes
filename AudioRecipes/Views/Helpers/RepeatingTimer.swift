import Foundation

/// RepeatingTimer mimics the API of DispatchSourceTimer but in a way that prevents
/// crashes that occur from calling resume multiple times on a timer that is
/// already resumed (noted by https://github.com/SiftScience/sift-ios/issues/52
public class RepeatingTimer {

    let timeInterval: TimeInterval
    let leftoverTime: TimeInterval
    
    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
        self.leftoverTime = 0.0
    }
    
    init(timeInterval: TimeInterval, leftoverTime: TimeInterval) {
        self.timeInterval = timeInterval
        self.leftoverTime = leftoverTime
    }
    
    private lazy var timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource()
        if(self.timeInterval > self.leftoverTime){
            t.schedule(deadline: .now() + self.timeInterval - self.leftoverTime, repeating: self.timeInterval)
        }
        else{
            t.schedule(deadline: .now(), repeating: self.timeInterval)
        }
        t.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
        return t
    }()

    var eventHandler: (() -> Void)?

    private enum State {
        case suspended
        case resumed
    }

    private var state: State = .suspended

    deinit {
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
        eventHandler = nil
    }

    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }

    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
    
    func cancel(){
        timer.setEventHandler {}
        timer.cancel()
        resume()
        eventHandler = nil
    }
}
