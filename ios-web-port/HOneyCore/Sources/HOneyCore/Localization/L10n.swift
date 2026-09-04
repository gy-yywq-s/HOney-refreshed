// Language (Web: lib/i18n.ts): English or 中文, chosen in Settings ›
// Appearance (System / English / 中文 on iPhone). Product nouns stay
// English in both — HOney, Home, Experiences, Timetable, History, Explore,
// Settings, P1–P6 — so the app keeps one identity; sentences, actions and
// helper copy switch. Keys are the English strings; an unknown key renders
// as itself, so nothing can ever go blank.

import Foundation
import Observation

public enum AppLanguage: String, Sendable, Codable, CaseIterable, Equatable {
    case system, en, zh
}

@Observable
private final class L10nState: @unchecked Sendable {
    var language: AppLanguage = .system
}

public enum L10n {
    private static let state = L10nState()
    nonisolated(unsafe) public static var systemPrefersChinese: @Sendable () -> Bool = {
        Locale.preferredLanguages.first.map { $0.hasPrefix("zh") } ?? false
    }

    public static var language: AppLanguage {
        get { state.language }
        set { state.language = newValue }
    }

    /// The language actually in effect.
    public static var effective: AppLanguage {
        switch state.language {
        case .system: return systemPrefersChinese() ? .zh : .en
        default: return state.language
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
        "Pull to refresh": "下拉刷新",
        "Release to refresh": "松开刷新",
        "Refreshing…": "正在刷新…",
        "Updated": "已更新",
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
        // home + notices (Web 2026-09-03/04)
        "Related to you": "和你有关",
        "From school": "学校通知",
        "All notices": "全部通知",
        "Open as a page": "在整页中打开",
        "Mark all read": "全部标为已读",
        "Notice": "通知",
        "Edited": "已修改",
        "Published by the school on the portal.": "由学校发布在学校门户上。",
        "This notice is no longer in the school's list.": "这条通知已不在学校的列表里。",
        "The school has not published anything yet.": "学校还没有发布任何通知。",
        "New": "新",
        "Signed in": "已登录",
        "Sign in once": "登录一次",
        "Yours": "你的",
        // posts
        "This resonates with me": "我有共鸣",
        "Write your own": "写下你自己的",
        "Post options": "帖子操作",
        "Report this experience": "举报这条经历",
        "Report sent": "举报已提交",
        "Disagreeing is not a report — use the reaction for that. Reports are for rule problems only, and no free text is collected.": "不同意不算举报——那用共鸣或写下你自己的。举报只用于违反规则的问题，且不收集任何自由文本。",
        "Thanks. The post gets re-checked automatically under the current community rules — reports flag a rule problem; they are never a vote.": "谢谢。这条帖子会按当前社区规则自动重新检查——举报是标记规则问题，不是投票。",
        "Private or identifying information": "私人或可识别身份的信息",
        "Targeted abuse or a slur": "针对性辱骂或歧视性用语",
        "It is about a student": "这是关于某个学生的",
        "A serious matter that should not be in the feed": "不适合出现在信息流里的严重事项",
        "Rumor, spam, or not a real experience": "谣言、垃圾内容，或并非真实经历",
        "Another community-rule problem": "其他违反社区规则的问题",
        // timetable + history
        "Syncing with the school…": "正在与学校同步…",
        "Synced": "已同步",
        "lessons": "节课",
        "History": "History",
        "or pull up at the end": "或到底后上拉",
        "Open the timetable": "打开课表",
        "This lesson hasn't started yet. You can share what it was like once it has begun.": "这节课还没开始。上课之后就可以分享它的体验。",
        // composer
        "Doesn't belong here?": "不适合发在这里？",
        "Send it to the school": "直接反馈给学校",
        "Send this to the school instead": "改为发送给学校",
        "Restore post controls": "恢复帖子控制",
        "Draft saved on this device": "草稿已保存在本设备",
        // settings › at school
        "At school": "在学校",
        "Campus card": "一卡通",
        "Balance, spending": "余额、消费",
        "Weekend stay": "周末留宿",
        "Days on record": "已记录的日期",
        "School record": "学校记录",
        "What the school has recorded": "学校记录在案的内容",
        "Lesson feedback": "课程反馈",
        "Lessons waiting for yours": "等待你评价的课",
        "Feedback to the school": "反馈给学校",
        "Sent from your school account": "以你的学校账号发送",
        "Sent from your school account — not anonymous.": "以你的学校账号发送——不是匿名。",
        "What should the school know?": "想让学校知道什么？",
        "Send to the school": "发送给学校",
        "Sent to the school.": "已发送给学校。",
        "The school connection needs renewing.": "学校连接需要重新登录。",
        "The school could not be reached.": "连不上学校系统。",
        "The school could not be reached just now.": "现在连不上学校系统。",
        "HOney needs the school connection for this.": "这里需要学校连接。",
        "Read live.": "实时读取。",
        "Balance": "余额",
        "Card": "卡号",
        "in use": "使用中",
        "not in use": "未启用",
        "General": "自充值",
        "Subsidy": "补助",
        "Top up": "充值",
        "In the portal": "在门户里",
        "Spending": "消费记录",
        "Nothing on this card yet.": "这张卡还没有消费记录。",
        "Top-ups": "充值记录",
        "No card is registered to you.": "你名下没有一卡通。",
        "Top up the card": "一卡通充值",
        "Opens an Alipay link.": "会打开支付宝链接。",
        "Continue to pay": "去付款",
        "The payment page is open.": "付款页面已打开。",
        "The school opened the order but did not say where to pay. Open the school portal and finish it there.": "学校已经开单，但没有给出付款地址。请到学校门户里完成付款。",
        "Could not reach HOney. Try again.": "连不上 HOney，请重试。",
        "Open days": "可选日期",
        "Apply": "申请",
        "Applied.": "已提交。",
        "Withdrawn.": "已撤回。",
        "On record": "已记录",
        "Nothing booked.": "还没有留宿。",
        "Withdraw": "撤回",
        "Withdraw this weekend?": "撤回这次留宿？",
        "Nothing on record.": "没有任何记录。",
        "Reason": "原因",
        "Nothing waiting.": "没有待评的课。",
        "Rating": "评分",
        "Issues (if applicable)": "问题（如有）",
        "What could be improved?": "有什么可以改进的？",
        "Choose a rating.": "请先评分。",
        "Send": "提交",
        "Sent.": "已提交。",
        "Working…": "处理中…",
    ]
}
