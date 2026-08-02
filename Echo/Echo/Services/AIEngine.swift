import Foundation
import NaturalLanguage
import SwiftData

struct AIInsight: Identifiable {
 let id = UUID(); let type: InsightType; let title: String; let detail: String; let icon: String; let severity: InsightSeverity
 enum InsightType { case healthWarning, sentimentTrend, topicExtract, actionItem, patternDetect, smartSuggestion }
 enum InsightSeverity: String { case critical, warning, positive, info }
}

struct RelationshipHealth: Identifiable {
 let id = UUID(); let contactId: String; let score: Int; let level: HealthLevel; let factors: [HealthFactor]; let recommendation: String
 enum HealthLevel: String {
  case thriving="thrive", stable="stable", atRisk="at_risk", fading="fading", critical="critical"
  var label: String { switch self { case .thriving: return "蓬勃发展"; case .stable: return "稳定"; case .atRisk: return "需要关注"; case .fading: return "正在淡化"; case .critical: return "危急" } }
  var icon: String { switch self { case .thriving: return "sparkles"; case .stable: return "checkmark.circle"; case .atRisk: return "exclamationmark.circle"; case .fading: return "clock.badge.exclamationmark"; case .critical: return "exclamationmark.triangle" } }
  var color: String { switch self { case .thriving: return "#30D158"; case .stable: return "#0A84FF"; case .atRisk: return "#FF9F0A"; case .fading: return "#FF6B35"; case .critical: return "#FF453A" } }
 }
 struct HealthFactor { let name: String; let score: Double; let detail: String }
}

struct AIOpeningLine { let id = UUID(); let text: String; let context: String; let channel: InteractionType }
struct AIWeeklySummary { let weekRange: String; let totalReachouts: Int; let newConnections: Int; let relationshipsStrengthened: Int; let relationshipsAtRisk: Int; let topInsights: [AIInsight]; let recommendedActions: [String]; let healthDistribution: [RelationshipHealth.HealthLevel: Int] }
struct DuplicatePair { let contactA: EchoContact; let contactB: EchoContact; let confidence: Double; let reason: String }
struct SmartReminder { let contact: EchoContact; let suggestedTime: Date; let reason: String; let suggestedChannel: InteractionType; let priority: ReminderPriority; enum ReminderPriority: String { case urgent, important, nice="nice_to_have" } }
struct RelationshipGoal: Identifiable { let id = UUID(); let contact: EchoContact; let goal: String; let detail: String; let priority: GoalPriority; enum GoalPriority: Int { case low=0, medium=1, high=2 } }
struct BatchGroup: Identifiable { let id = UUID(); let title: String; let subtitle: String; let contacts: [EchoContact]; let icon: String }

final class AIEngine {
 // 1. Health Score (0-100)
 static func healthScore(for c: EchoContact) -> RelationshipHealth {
  let ints = c.interactions.sorted { $0.date < $1.date }; let notes = c.notes.sorted { $0.createdAt < $1.createdAt }
  let rs = calcRecency(last: ints.last?.date); let fs = calcFreq(ints: ints, days: 90, exp: 4); let ss = calcSentiment(notes: notes); let ds = calcDiversity(ints: ints); let cs = calcConsistency(ints: ints)
  let rf = RelationshipHealth.HealthFactor(name: "联系间隔", score: rs, detail: recencyDetail(last: ints.last?.date))
  let ff = RelationshipHealth.HealthFactor(name: "互动频率", score: fs, detail: freqDetail(ints: ints, days: 90))
  let sf = RelationshipHealth.HealthFactor(name: "情感质量", score: ss, detail: sentimentDetail(notes: notes))
  let df = RelationshipHealth.HealthFactor(name: "互动多样性", score: ds, detail: "使用了\(Set(ints.map { $0.type }).count)种互动方式")
  let cf = RelationshipHealth.HealthFactor(name: "互动一致性", score: cs, detail: "共\(ints.count)次互动")
  let total = Int(rs*0.35 + fs*0.25 + ss*0.15 + ds*0.15 + cs*0.10)
  let lvl = level(score: total)
  let rec = recommendation(c: c, lvl: lvl, factors: [rf,ff,sf,df,cf])
  return RelationshipHealth(contactId: c.systemIdentifier, score: total, level: lvl, factors: [rf,ff,sf,df,cf], recommendation: rec)
 }
 // 2. Smart Reminder
 static func smartReminder(for c: EchoContact) -> SmartReminder? {
  let ints = c.interactions
  guard !ints.isEmpty else { let t = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(); let m = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: t) ?? t; return SmartReminder(contact: c, suggestedTime: m, reason: "你们还没有互动过，建议主动打个招呼", suggestedChannel: .messaged, priority: .important) }
  let hours = ints.reduce(into: [Int:Int]()) { $0[Calendar.current.component(.hour, from: $1.date), default: 0] += 1 }
  let topHour = hours.max { $0.value < $1.value }?.key ?? 10
  let ch = mostUsed(ints: ints)
  let days = c.lastReachedOut.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 999
n  let p: SmartReminder.ReminderPriority; let r: String
  if days >= 30 { p = .urgent; r = "已经\(days)天没联系了，关系正在淡化" } else if days >= 14 { p = .important; r = "已经\(days)天没联系了，是时候打个招呼了" } else if days >= 7 { p = .nice; r = "一周没联系了，可以简单问候一下" } else { return nil }
  let nd = Calendar.current.date(byAdding: .day, value: p == .urgent ? 0 : 1, to: Date()) ?? Date()
  let st = Calendar.current.date(bySettingHour: topHour, minute: 0, second: 0, of: nd) ?? nd
  return SmartReminder(contact: c, suggestedTime: st, reason: r, suggestedChannel: ch, priority: p)
 }
 // 3. AI Insights
 static func generateInsights(for c: EchoContact) -> [AIInsight] {
  var ins: [AIInsight] = []; let h = healthScore(for: c)
  if h.level == .critical || h.level == .fading { ins.append(AIInsight(type: .healthWarning, title: "关系健康预警", detail: "健康评分 \(h.score)/100 — \(h.level.label)。\(h.recommendation)", icon: h.level.icon, severity: h.level == .critical ? .critical : .warning)) }
  else if h.level == .thriving { ins.append(AIInsight(type: .healthWarning, title: "关系状态优秀", detail: "健康评分 \(h.score)/100 — 你和 \(c.givenName) 的关系蓬勃发展！", icon: "sparkles", severity: .positive)) }
  let notes = c.notes.sorted { $0.createdAt < $1.createdAt }
  if notes.count >= 2 { let t = sentimentTrend(notes: notes); if t.0 { ins.append(AIInsight(type: .sentimentTrend, title: "情感趋势下降", detail: "最近笔记的情感倾向有所下降，建议主动联系", icon: "chart.line.downtrend", severity: .warning)) } else if t.1 { ins.append(AIInsight(type: .sentimentTrend, title: "情感趋势上升", detail: "你们的互动越来越积极，继续保持！", icon: "chart.line.uptrend", severity: .positive)) } }
  let txt = notes.map { $0.text }.joined(separator: " ")
  if !txt.isEmpty { let topics = extractTopics(txt: txt); if !topics.isEmpty { ins.append(AIInsight(type: .topicExtract, title: "常见话题", detail: "你们经常聊到：\(topics.joined(separator: "、"))", icon: "tag", severity: .info)) } }
  let actions = detectActions(notes: notes)
  for a in actions.prefix(3) { ins.append(AIInsight(type: .actionItem, title: "待办提醒", detail: a, icon: "checkmark.circle", severity: .info)) }
  if !c.interactions.isEmpty { let p = pattern(ints: c.interactions); if !p.isEmpty { ins.append(AIInsight(type: .patternDetect, title: "互动模式", detail: p, icon: "waveform", severity: .info)) } }
  if let s = smartSuggestion(c: c, h: h) { ins.append(AIInsight(type: .smartSuggestion, title: "AI 建议", detail: s, icon: "lightbulb", severity: .info)) }
  return ins
 }
 // 4. Smart Search
 static func smartSearch(query: String, in contacts: [EchoContact]) -> [(EchoContact, String)] {
  guard !query.isEmpty else { return [] }; let q = query.lowercased(); var res: [(EchoContact, String)] = []
  for c in contacts { if c.fullName.lowercased().contains(q) { res.append((c, "名字匹配")); continue }; if let co = c.companyName?.lowercased(), co.contains(q) { res.append((c, "公司: \(c.companyName ?? "")")); continue }; for n in c.notes { if n.text.lowercased().contains(q) { res.append((c, "笔记: \(snippet(q: q, text: n.text))")); break } }; for i in c.interactions { if let s = i.summary?.lowercased(), s.contains(q) { res.append((c, "互动: \(snippet(q: q, text: i.summary ?? ""))")); break } } }
  return res
 }
 // 5. Goals
 static func suggestRelationshipGoals(contacts: [EchoContact]) -> [RelationshipGoal] {
  var g: [RelationshipGoal] = []
  for c in contacts { let h = healthScore(for: c); if h.level == .critical || h.level == .fading { g.append(RelationshipGoal(contact: c, goal: "重新建立联系", detail: "距上次联系已超过30天", priority: .high)) } else if h.level == .atRisk { g.append(RelationshipGoal(contact: c, goal: "提升联系频率", detail: "互动频率偏低", priority: .medium)) } else if h.level == .stable { let a = detectActions(notes: c.notes); if let f = a.first { g.append(RelationshipGoal(contact: c, goal: "完成待办事项", detail: f, priority: .medium)) } } }
  return g.sorted { $0.priority.rawValue > $1.priority.rawValue }
 }
 // 6. Opening Lines
 static func generateOpeningLines(for c: EchoContact, channel: InteractionType) -> [AIOpeningLine] {
  var l: [AIOpeningLine] = []; let n = c.givenName; let d = c.lastReachedOut.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? -1
  if d < 0 { l.append(AIOpeningLine(text: "Hey \(n)! 好久没聊了，最近怎么样？", context: "首次联系", channel: channel)); l.append(AIOpeningLine(text: "Hi \(n)，想到你了，最近一切都好吧？", context: "首次联系", channel: channel)) }
  else if d <= 3 { l.append(AIOpeningLine(text: "Hey \(n)，接着上次聊的，后续怎么样了？", context: "刚联系过", channel: channel)); l.append(AIOpeningLine(text: "Hi \(n)，分享一个你可能感兴趣的东西", context: "主动分享", channel: channel)) }
  else if d <= 14 { l.append(AIOpeningLine(text: "Hey \(n)，两周没聊了，最近忙什么呢？", context: "两周未联系", channel: channel)); l.append(AIOpeningLine(text: "Hi \(n)，想起你了，有空聚一下吗？", context: "两周未联系", channel: channel)) }
  else if d <= 30 { l.append(AIOpeningLine(text: "Hey \(n)，好久不见！最近怎么样？", context: "一个月未联系", channel: channel)); l.append(AIOpeningLine(text: "Hi \(n)，今天突然想到你，一切都还好吗？", context: "一个月未联系", channel: channel)) }
  else { l.append(AIOpeningLine(text: "\(n)，太久没联系了，想念你！哪天聚一下？", context: "超过一个月未联系", channel: channel)); l.append(AIOpeningLine(text: "Hi \(n)，我意识到我们很久没联系了，想你了，最近怎么样？", context: "超过一个月未联系", channel: channel)) }
  switch channel { case .called: l.append(AIOpeningLine(text: "\(n)，有空打个电话聊聊？", context: "电话渠道", channel: channel)); case .messaged: l.append(AIOpeningLine(text: "在吗？想你了，聊聊？", context: "消息渠道", channel: channel)); case .emailed: l.append(AIOpeningLine(text: "Hi \(n)，\n\n最近怎么样？想给你发个邮件问候一下...\n", context: "邮件渠道", channel: channel)); case .metInPerson: l.append(AIOpeningLine(text: "\(n)，有空出来坐坐？喝杯咖啡？", context: "见面邀约", channel: channel)); case .reachedOut: break }
  let topics = extractTopics(txt: c.notes.map { $0.text }.joined(separator: " "))
  if let t = topics.first { l.append(AIOpeningLine(text: "Hey \(n)，上次聊到\(t)，后来怎么样了？", context: "基于上次聊天话题: \(t)", channel: channel)) }
  return l
 }
 // 7. Batch
 static func batchSuggestions(contacts: [EchoContact]) -> [BatchGroup] {
  var g: [BatchGroup] = []
  let urgent = contacts.filter { c in let d = c.lastReachedOut.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 999; return d >= 30 }
  if !urgent.isEmpty { g.append(BatchGroup(title: "紧急联系", subtitle: "超过30天未联系，关系正在淡化", contacts: urgent, icon: "exclamationmark.triangle")) }
  let week = contacts.filter { c in let d = c.lastReachedOut.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 999; return d >= 7 && d < 30 }
  if !week.isEmpty { g.append(BatchGroup(title: "本周建议联系", subtitle: "7-30天未联系，保持热度", contacts: week, icon: "calendar")) }
  return g
 }
 // 8. Voice Note
 static func analyzeVoiceNote(transcript: String) -> (sentiment: Double, topics: [String], actionItems: [String]) { return (sentiment(txt: transcript), extractTopics(txt: transcript), detectActions(from: transcript)) }
 // 9. Dedup
 static func findDuplicates(in contacts: [EchoContact]) -> [DuplicatePair] {
  var d: [DuplicatePair] = []
  for i in 0..<contacts.count { for j in (i+1)..<contacts.count { let conf = dupConf(a: contacts[i], b: contacts[j]); if conf >= 0.7 { let r: String; if let p1 = contacts[i].phoneNumber, let p2 = contacts[j].phoneNumber, p1 == p2 { r = "电话号码相同" } else if let e1 = contacts[i].emailAddress, let e2 = contacts[j].emailAddress, e1 == e2 { r = "邮箱相同" } else { r = "名字高度相似" }; d.append(DuplicatePair(contactA: contacts[i], contactB: contacts[j], confidence: conf, reason: r)) } } }
  return d.sorted { $0.confidence > $1.confidence }
 }
 // 10. CSV
 static func mapCSVFields(headers: [String]) -> [String: String] { let m: [String:String] = ["name":"fullName","姓名":"fullName","phone":"phoneNumber","电话":"phoneNumber","email":"emailAddress","邮箱":"emailAddress","company":"companyName","公司":"companyName","title":"jobTitle","职位":"jobTitle","notes":"note","备注":"note"]; var r: [String:String] = [:]; for h in headers { if let v = m[h.lowercased().trimmingCharacters(in: .whitespaces)] { r[h] = v } }; return r }
 // 11. Weekly Summary
 static func generateWeeklySummary(contacts: [EchoContact]) -> AIWeeklySummary {
  let cal = Calendar.current; let now = Date(); guard let wk = cal.date(byAdding: .day, value: -7, to: now) else { return AIWeeklySummary(weekRange: "", totalReachouts: 0, newConnections: 0, relationshipsStrengthened: 0, relationshipsAtRisk: 0, topInsights: [], recommendedActions: [], healthDistribution: [:]) }
  let ri = contacts.flatMap { $0.interactions }.filter { $0.date >= wk }; let rc = Set(ri.map { $0.contact?.systemIdentifier ?? "" })
  let to = ri.count; let nc = contacts.filter { $0.createdAt >= wk }.count
  let st = contacts.filter { c in healthScore(for: c).level == .thriving && rc.contains(c.systemIdentifier) }.count
  let ar = contacts.filter { c in let l = healthScore(for: c).level; return l == .atRisk || l == .fading || l == .critical }.count
  var dist: [RelationshipHealth.HealthLevel: Int] = [:]; for c in contacts { dist[healthScore(for: c).level, default: 0] += 1 }
  let ti = contacts.flatMap { generateInsights(for: $0) }.sorted { rank($0.severity) > rank($1.severity) }.prefix(5).map { $0 }
  var act: [String] = []; let u = contacts.filter { c in let d = c.lastReachedOut.map { cal.dateComponents([.day], from: $0, to: now).day ?? 0 } ?? 999; return d >= 30 }; if !u.isEmpty { act.append("联系 \(u.count) 位超过30天未联系的人") }; let w = contacts.filter { c in let d = c.lastReachedOut.map { cal.dateComponents([.day], from: $0, to: now).day ?? 0 } ?? 999; return d >= 7 && d < 30 }; if !w.isEmpty { act.append("给 \(w.count) 位一周未联系的人发个问候") }
  let f = DateFormatter(); f.dateFormat = "M月d日"
  return AIWeeklySummary(weekRange: "\(f.string(from: wk)) - \(f.string(from: now))", totalReachouts: to, newConnections: nc, relationshipsStrengthened: st, relationshipsAtRisk: ar, topInsights: Array(ti), recommendedActions: act, healthDistribution: dist)
 }
 // 12. Smart Notifications
 static func generateSmartNotifications(contacts: [EchoContact]) -> [SmartReminder] { var r: [SmartReminder] = []; for c in contacts { if let s = smartReminder(for: c) { r.append(s) } }; let o: [SmartReminder.ReminderPriority: Int] = [.urgent: 0, .important: 1, .nice: 2]; return r.sorted { (o[$0.priority] ?? 3) < (o[$1.priority] ?? 3) } }
 // Private
 private static func calcRecency(last: Date?) -> Double { guard let l = last else { return 0 }; let d = Calendar.current.dateComponents([.day], from: l, to: Date()).day ?? 0; if d <= 3 { return 1.0 }; if d <= 7 { return 0.85 }; if d <= 14 { return 0.65 }; if d <= 30 { return 0.35 }; if d <= 60 { return 0.15 }; return 0.05 }
 private static func calcFreq(ints: [Interaction], days: Int, exp: Int) -> Double { let c = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date(); let n = ints.filter { $0.date >= c }.count; return min(Double(n) / Double(exp), 1.0) }
 private static func calcSentiment(notes: [Note]) -> Double { guard !notes.isEmpty else { return 0.5 }; return notes.suffix(5).map { sentiment(txt: $0.text) }.reduce(0, +) / Double(min(notes.count, 5)) }
 private static func calcDiversity(ints: [Interaction]) -> Double { return min(Double(Set(ints.map { $0.type }).count) / Double(InteractionType.allCases.count) * 1.5, 1.0) }
 private static func calcConsistency(ints: [Interaction]) -> Double { guard ints.count >= 3 else { return 0.5 }; let d = ints.sorted { $0.date < $1.date }.map { $0.date }; var g: [Double] = []; for i in 1..<d.count { g.append(d[i].timeIntervalSince(d[i-1]) / 86400) }; let a = g.reduce(0, +) / Double(g.count); let v = g.reduce(0) { $0 + ($1 - a) * ($1 - a) } / Double(g.count); let cv = a > 0 ? sqrt(v) / a : 1.0; if cv <= 0.3 { return 1.0 }; if cv <= 0.6 { return 0.7 }; if cv <= 1.0 { return 0.4 }; return 0.2 }
 private static func sentiment(txt: String) -> Double { guard !txt.isEmpty else { return 0.5 }; let t = NLTagger(tagSchemes: [.sentimentScore]); t.string = txt; let (tag, _) = t.tag(at: txt.startIndex, unit: .paragraph, scheme: .sentimentScore); if let s = Double(tag?.rawValue ?? "0") { return max(0, min(1, (s + 1.0) / 2.0)) }; return 0.5 }
 private static func sentimentTrend(notes: [Note]) -> (Bool, Bool) { guard notes.count >= 2 else { return (false, false) }; let h = notes.count / 2; let f1 = notes.prefix(h).map { sentiment(txt: $0.text) }.reduce(0, +) / max(Double(h), 1); let f2 = notes.suffix(notes.count - h).map { sentiment(txt: $0.text) }.reduce(0, +) / max(Double(notes.count - h), 1); let d = f2 - f1; return (d < -0.15, d > 0.15) }
 private static func extractTopics(txt: String) -> [String] { guard !txt.isEmpty else { return [] }; let t = NLTagger(tagSchemes: [.nameType]); t.string = txt; var tp: [String] = []; t.enumerateTags(in: txt.startIndex..<txt.endIndex, unit: .word, scheme: .nameType, options: [.skipWhitespace]) { tag, r in if tag != nil { let w = String(txt[r]); if w.count >= 2 && !tp.contains(w) { tp.append(w) } }; return true }; return Array(tp.prefix(5)) }
 private static func detectActions(notes: [Note]) -> [String] { let p = ["记得","别忘了","需要","应该","计划","打算","TODO","待办","跟进","下次","答应","承诺","约","下周","明天","remind","should","plan to"]; var i: [String] = []; for n in notes { for s in n.text.components(separatedBy: CharacterSet(charactersIn: "。.！!？?\n")) { let t = s.trimmingCharacters(in: .whitespaces); if t.count >= 5 && p.contains(where: { t.lowercased().contains($0.lowercased()) }) { i.append(t) } } }; return i }
 private static func detectActions(from txt: String) -> [String] { detectActions(notes: [Note(text: txt, contact: nil)]) }
 private static func pattern(ints: [Interaction]) -> String { guard ints.count >= 3 else { return "" }; let tc = ints.reduce(into: [InteractionType: Int]()) { $0[$1.type, default: 0] += 1 }; if let top = tc.max(by: { $0.value < $1.value }) { let s = ints.sorted { $0.date < $1.date }; let ag = s.count > 1 ? s.last!.date.timeIntervalSince(s.first!.date) / Double(s.count - 1) / 86400 : 0; return "你们最常通过「\(top.key.label)」联系，平均间隔 \(String(format: "%.1f", ag)) 天" }; return "" }
 private static func smartSuggestion(c: EchoContact, h: RelationshipHealth) -> String? { switch h.level { case .critical: return "\(c.givenName) 的关系评分仅 \(h.score) 分，建议立即主动联系"; case .fading: return "建议本周内联系 \(c.givenName)"; case .atRisk: if let w = h.factors.min(by: { $0.score < $1.score }) { return "\(w.name)偏低，\(w.detail)" }; return "建议增加联系频率"; case .stable: return "关系稳定，可以尝试更多元的互动方式"; case .thriving: return "关系很好！考虑主动分享有趣的内容保持热度" } }
 private static func level(score: Int) -> RelationshipHealth.HealthLevel { switch score { case 80...100: return .thriving; case 60..<80: return .stable; case 40..<60: return .atRisk; case 20..<40: return .fading; default: return .critical } }
 private static func recencyDetail(last: Date?) -> String { guard let l = last else { return "从未联系过" }; let d = Calendar.current.dateComponents([.day], from: l, to: Date()).day ?? 0; if d <= 3 { return "\(d)天前刚联系过" }; if d <= 14 { return "已\(d)天未联系" }; return "已\(d)天未联系，关系可能淡化" }
 private static func freqDetail(ints: [Interaction], days: Int) -> String { let c = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date(); return "过去\(days)天互动\(ints.filter { $0.date >= c }.count)次" }
 private static func sentimentDetail(notes: [Note]) -> String { guard !notes.isEmpty else { return "暂无笔记" }; let a = notes.suffix(5).map { sentiment(txt: $0.text) }.reduce(0, +) / Double(min(notes.count, 5)); if a > 0.65 { return "笔记情感积极" }; if a > 0.45 { return "笔记情感中性" }; return "笔记情感偏消极" }
 private static func mostUsed(ints: [Interaction]) -> InteractionType { let c = ints.reduce(into: [InteractionType: Int]()) { $0[$1.type, default: 0] += 1 }; return c.max(by: { $0.value < $1.value })?.key ?? .messaged }
 private static func dupConf(a: EchoContact, b: EchoContact) -> Double { if let p1 = a.phoneNumber, let p2 = b.phoneNumber { let c1 = p1.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression); let c2 = p2.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression); if c1 == c2 && c1.count >= 8 { return 1.0 }; if c1.suffix(8) == c2.suffix(8) { return 0.9 } }; if let e1 = a.emailAddress?.lowercased(), let e2 = b.emailAddress?.lowercased(), e1 == e2 { return 1.0 }; let s1 = Set(a.fullName.lowercased()); let s2 = Set(b.fullName.lowercased()); let i = s1.intersection(s2).count; let u = s1.union(s2).count; return u > 0 ? Double(i) / Double(u) : 0 }
 private static func snippet(q: String, text: String) -> String { guard let r = text.lowercased().range(of: q) else { return String(text.prefix(50)) }; let s = text.index(r.lowerBound, offsetBy: -20, limitedBy: text.startIndex) ?? text.startIndex; let e = text.index(r.upperBound, offsetBy: 20, limitedBy: text.endIndex) ?? text.endIndex; let sn = String(text[s..<e]); return sn.count > 60 ? String(sn.prefix(60)) + "..." : sn }
 private static func rank(_ s: AIInsight.InsightSeverity) -> Int { switch s { case .critical: return 4; case .warning: return 3; case .positive: return 2; case .info: return 1 } }
 private static func recommendation(c: EchoContact, lvl: RelationshipHealth.HealthLevel, factors: [RelationshipHealth.HealthFactor]) -> String { switch lvl { case .thriving: return "关系状态优秀，继续保持"; case .stable: return "关系稳定，可以尝试增加更多元互动"; case .atRisk: if let w = factors.min(by: { $0.score < $1.score }) { return "\(w.name)需要提升 — \(w.detail)" }; return "建议主动联系"; case .fading: return "关系正在淡化，建议本周内主动联系 \(c.givenName)"; case .critical: return "关系危急！建议立即联系 \(c.givenName)" } }
}

extension Note { convenience init(text: String, contact: EchoContact?) { self.init(); self.text = text; if let c = contact { self.contact = c } } }
