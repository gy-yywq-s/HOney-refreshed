// Language (Web: lib/i18n.ts): English or 中文, chosen in Settings ›
// Appearance (System / English / 中文 on iPhone). Product nouns stay
// English in both — HOney, Home, Experiences, Timetable, History, Explore,
// Settings, P1–P6 — so the app keeps one identity; sentences, actions and
// helper copy switch. Keys are the English strings; an unknown key renders
// as itself, so nothing can ever go blank.

import Foundation

public enum AppLanguage: String, Sendable, Codable, CaseIterable, Equatable {
    case system, en, zh
}

public enum L10n {
    nonisolated(unsafe) private static var current: AppLanguage = .system
    nonisolated(unsafe) public static var systemPrefersChinese: @Sendable () -> Bool = {
        Locale.preferredLanguages.first.map { $0.hasPrefix("zh") } ?? false
    }

    public static var language: AppLanguage {
        get { current }
        set { current = newValue }
    }

    /// The language actually in effect.
    public static var effective: AppLanguage {
        switch current {
        case .system: return systemPrefersChinese() ? .zh : .en
        default: return current
        }
    }

    public static var isChinese: Bool { effective == .zh }

    public static func t(_ key: String) -> String {
        guard isChinese else { return key }
        return zh[key] ?? key
    }

    /// "Hi, Name" / "你好，Name"
    public static func greeting(_ name: String) -> String {
        isChinese ? "你好，\(name)" : "Hi, \(name)"
    }

    static let zh: [String: String] = [
        // shell
        "Back": "返回",
        "Try again": "重试",
        "Could not reach the HOney server. Check your connection and try again.": "连不上 HOney 服务器，请检查网络后重试。",
        "Could not load your account.": "无法加载你的账户。",
        "Done": "完成",
        "Cancel": "取消",
        "OK": "好",
        // home
        "Now": "现在",
        "Next lesson": "下一节课",
        "Nothing coming up": "暂无课程",
        "No upcoming lessons in your timetable.": "课表里没有接下来的课。",
        "From your classes": "来自你的课",
        "When someone shares an experience connected to your classes, it will appear here.": "有人分享与你的课相关的经历时，会显示在这里。",
        "See all": "查看全部",
        "School Portal": "School Portal",
        "Official site": "学校官网",
        "Open the official site": "打开学校官网",
        "left": "后结束",
        "In": "还有",
        "Tomorrow": "明天",
        // feed
        "Why this space exists": "为什么有这个空间",
        "Find someone or something": "找老师、课程、地点或食物",
        "Your notes & posts": "我的笔记与帖子",
        "Share an experience": "分享一段经历",
        "Nothing from your classes yet.": "你的课还没有人分享。",
        "A small honest note is enough.": "一小段真实的话就够了。",
        "Share the first one": "分享第一条",
        "Nothing has been shared yet.": "还没有人分享。",
        "A short thought is enough to begin.": "一个简短的想法就可以开始。",
        "Read more": "展开",
        "You’re all caught up.": "都看完了。",
        "New experiences are available": "有新的经历",
        "Anything from school you want to put into words?": "学校里有什么想写下来的吗？",
        "Matches my experience": "和我的经历一样",
        "Doesn’t match my experience": "和我的经历不一样",
        "More options": "更多",
        "Report": "举报",
        // explore
        "Teachers, courses, places and food.": "老师、课程、地点和食物。",
        "Search names and experiences": "搜索名字和经历",
        "Clear search": "清除搜索",
        "Teachers": "老师",
        "Courses": "课程",
        "Places": "地点",
        "Food": "食物",
        "Recently opened": "最近打开",
        "Nothing by that name.": "没有这个名字。",
        "Nothing here yet.": "这里还没有内容。",
        "from your classes": "来自你的课",
        // composer
        "What is this about?": "这段经历是关于什么？",
        "One of your own lessons, or a teacher, course, place or dish.": "你上过的一节课，或一位老师、一门课程、一个地点、一道菜。",
        "Recent lessons": "最近的课",
        "See full History": "查看完整 History",
        "Other school context": "学校里的其他",
        "Teachers, courses, places and food": "老师、课程、地点和食物",
        "No lessons in your history yet.": "History 里还没有课。",
        "About": "关于",
        "Change": "更换",
        "What was it like for you?": "对你来说这是什么样的？",
        "A moment, a pattern, or just a feeling. Specific context can help, but it is not required.": "一个瞬间、一种模式，或只是一种感觉。具体一点会有帮助，但不是必须。",
        "Your own experience, in your own words": "用你自己的话，写你自己的经历",
        "Saved on this iPhone": "已保存在这台 iPhone",
        "Saving…": "保存中…",
        "Continue to share": "继续分享",
        "Keep private": "保留为私密",
        "Checking…": "检查中…",
        "Share now": "现在分享",
        "Check and share": "重新检查并分享",
        "Public sharing runs a text check. Published Experiences are stored without an ordinary author field.": "公开分享前会做一次文字检查。公开的经历不带普通的作者字段。",
        "How anonymity works": "匿名如何运作",
        "Rating (dishes only — optional)": "评分（仅菜品，可不填）",
        "Before you share": "分享之前",
        "This can be shared as it is. Is there anything that would help someone understand what you mean?": "这段可以直接分享。还有什么能帮别人理解你的意思吗？",
        "Share as written": "按原样分享",
        "Add a little context": "补充一点背景",
        "Publishing can wait": "发布可以等等",
        "This is a pause, not a judgment about your experience.": "这只是暂停，不是对你的经历下判断。",
        "Cooling · you can share these words in": "冷静期 · 这段文字可以分享的时间：",
        "Edit them to say it differently and check again now.": "也可以现在改一改措辞，重新检查。",
        "Share in": "可分享：",
        "Shared.": "已分享。",
        "Kept private": "已保留为私密",
        // mine
        "Private notes": "私密笔记",
        "Shared": "已分享",
        "Post controls on this iPhone": "帖子的控制权保存在这台 iPhone",
        "Manage": "管理",
        "Keep something private or share an Experience when you are ready.": "准备好了就分享一段经历，或先私密地留着。",
        "Private · only on this iPhone": "私密 · 仅在这台 iPhone",
        "Cooling · you can share this in": "冷静期 · 可分享的时间：",
        "Pause over · ready to share": "冷静期结束 · 可以分享了",
        "Edit": "编辑",
        "Edit / share": "编辑 / 分享",
        "Delete": "删除",
        "Remove…": "移除…",
        "Hidden": "已隐藏",
        "Removed": "已移除",
        // timetable
        "Search lessons…": "搜索课程…",
        "Filters": "筛选",
        "Select": "选择",
        "Today": "今天",
        "Yesterday": "昨天",
        "Day": "日",
        "Week": "周",
        "Previous day": "前一天",
        "Next day": "后一天",
        "Previous week": "上一周",
        "Next week": "下一周",
        "Back to today": "回到今天",
        "This week": "本周",
        "No lessons today": "今天没有课",
        "Sync with school": "与学校同步",
        "Syncing with school…": "与学校同步中…",
        "Share what this was like": "分享这节课的感受",
        "Experiences with": "关于",
        "Experiences from this course": "这门课程的经历",
        "Open this day": "打开这一天",
        "More lesson details": "更多课程细节",
        "Lunch": "午休",
        "Dinner": "晚休",
        "Free": "空",
        // settings
        "Account": "账户",
        "School connection": "学校连接",
        "Sync, saved login, imported data": "同步、已保存的登录、导入的数据",
        "Share what a lesson was like…": "分享一节课的感受…",
        "Stay connected on this iPhone": "在这台 iPhone 保持连接",
        "Reconnects automatically after routine portal time-outs.": "学校门户例行超时后自动重新连接。",
        "Imported data": "导入的数据",
        "Timetable & lesson history": "课表与课程记录",
        "Experiences & privacy": "经历与隐私",
        "Your notes & post controls": "我的笔记与帖子控制",
        "Appearance": "外观",
        "Language": "语言",
        "System": "跟随系统",
        "Light": "浅色",
        "Dark": "深色",
        "Admin": "管理员",
        "Open Dash": "打开 Dash",
        "The operational console for admins.": "管理员的运维控制台。",
        "Build": "构建",
        "Sign out": "退出登录",
        "Sync now": "立即同步",
        "Reconnect": "重新连接",
        "Disconnect": "断开连接",
        "Delete account…": "删除账户…",
        "Delete imported data…": "删除导入的数据…",
        "Connected": "已连接",
        "Not connected": "未连接",
        "synced": "已同步",
        "never synced": "从未同步",
        "portal session expired": "门户会话已过期",
        "English": "English",
        "中文": "中文",
    ]
}
