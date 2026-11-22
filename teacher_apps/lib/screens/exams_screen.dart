import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/app_data.dart';
import '../widgets/common_widgets.dart';
import '../providers/teacher_provider.dart';
import 'question_paper_generator_screen.dart';
import 'marks_entry_screen.dart';

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacherProvider = Provider.of<TeacherProvider>(context);
    final examList = teacherProvider.examList;
    final classesList = teacherProvider.teacherClasses;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Exams & Grading'),
        leading: CircleIconButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.pop(context), size: 38),
        leadingWidth: 60,
        actions: [
          CircleIconButton(
            icon: Icons.add,
            onTap: () => _showAddExamSheet(context),
            bgColor: AppTheme.primary,
            iconColor: Colors.white,
            size: 38,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => teacherProvider.fetchExams(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // AI Studio & Marks Entry Action Banners
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuestionPaperGeneratorScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                    SizedBox(height: 8),
                    Text('AI Question Studio',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    Text('Generate CDC Papers',
                        style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MarksEntryScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppTheme.darkCardBorder : AppTheme.primary.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 26),
                    const SizedBox(height: 8),
                    Text('Enter Marks',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : AppTheme.dark)),
                    const Text('Theory + Practical (CDC)',
                        style: TextStyle(color: AppTheme.grey, fontSize: 10)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Summary row
          Row(children: [
            _ExamStat(label: 'Upcoming', value: '${examList.length}',
                color: AppTheme.primary),
            const SizedBox(width: 12),
            const _ExamStat(label: 'This Month', value: '3', color: AppTheme.orange),
            const SizedBox(width: 12),
            _ExamStat(label: 'Classes', value: '${classesList.length}',
                color: AppTheme.green),
          ]),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Upcoming Exams'),
          const SizedBox(height: 12),
          ...examList.asMap().entries.map((e) {
            final exam = e.value;
            return AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          color: Color(exam.colorHex),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('${exam.daysLeft}', style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w900,
                              color: exam.daysLeft <= 7 ? AppTheme.red : AppTheme.orange)),
                          const Text('days', style: TextStyle(
                              fontSize: 9, color: AppTheme.grey, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    exam.subject,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PillBadge(
                                  label: exam.type,
                                  color: AppTheme.primary.withOpacity(0.1),
                                  textColor: AppTheme.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exam.classSection,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 11, color: AppTheme.grey),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    '${exam.date} • ${exam.time}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.room_outlined, size: 11, color: AppTheme.grey),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    exam.room,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit_note, size: 18, color: AppTheme.primary),
                        label: const Text('Enter Subject Marks',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.primary)),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MarksEntryScreen(
                              initialExam: exam.type,
                              initialClass: exam.classSection,
                              initialSubject: exam.subject,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (e.key * 80).ms).slideY(begin: 0.1);
          }),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Past Exams'),
          const SizedBox(height: 12),
          ...List.generate(2, (i) => AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: AppTheme.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.quiz_outlined,
                    color: AppTheme.grey, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(['Mathematics Mid-Term', 'Statistics Quiz'][i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(['Grade 10 - A • Jul 15, 2025', 'Grade 12 - A • Jul 10, 2025'][i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(['Avg: 78%', 'Avg: 82%'][i],
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700, color: AppTheme.green)),
                Text(['32 students', '25 students'][i],
                    style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
              ]),
            ]),
          ).animate().fadeIn(delay: (i * 60).ms)),
        ]),
        ),
      ),
    );
  }

  void _showAddExamSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Schedule Exam', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.dark)),
          const SizedBox(height: 20),
          TextField(decoration: InputDecoration(labelText: 'Subject',
              filled: true, fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(decoration: InputDecoration(labelText: 'Date',
                filled: true, fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none)))),
            const SizedBox(width: 12),
            Expanded(child: TextField(decoration: InputDecoration(labelText: 'Room',
                filled: true, fillColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none)))),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text('Schedule Exam',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ExamStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ExamStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Text(value, style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
        ]),
      ),
    );
  }
}
