import BackgroundTasks

enum BackgroundRefresh {
    static let taskIdentifier = "com.sonicbattery.app.refresh"

    static func register() {
        let didRegister = BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            print("BackgroundRefresh: task fired at \(Date())")
            handle(task: task as! BGAppRefreshTask)
        }
        print("BackgroundRefresh: register() returned \(didRegister)")
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundRefresh: submitted request, earliest begin \(request.earliestBeginDate!)")
        } catch {
            print("BackgroundRefresh: could not schedule — \(error)")
        }
    }

    private static func handle(task: BGAppRefreshTask) {
        schedule() // queue the next wakeup before doing any work

        task.expirationHandler = {
            print("BackgroundRefresh: task expired before finishing")
            task.setTaskCompleted(success: false)
        }

        Task {
            await SonicActivityController.evaluateAndReact()
            task.setTaskCompleted(success: true)
            print("BackgroundRefresh: task completed")
        }
    }
}
