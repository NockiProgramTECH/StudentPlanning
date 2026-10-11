import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../theme.dart';

const courseColors = [Color(0xFFDFEEE8), Color(0xFFE8E9FA), Color(0xFFFFEBD9), Color(0xFFDFECF4)];

Color courseColor(String name) => courseColors[name.codeUnits.fold(0, (a, b) => a + b) % courseColors.length];

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;
  const CourseCard({super.key, required this.course, this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Container(width: 4, height: 62, decoration: BoxDecoration(
          color: course.kind == 'assessment' ? const Color(0xFFD85151)
            : course.deliveryMode == 'online' ? const Color(0xFFD6AE36) : teal, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 14),
        SizedBox(width: 53, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(course.start, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ink)),
          const SizedBox(height: 6),
          Text(course.end, style: const TextStyle(color: muted, fontSize: 12)),
        ])),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(course.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
          if (course.kind == 'assessment' || course.deliveryMode == 'online')
            Padding(padding: const EdgeInsets.only(top: 4, bottom: 3), child: Text(
              [if (course.kind == 'assessment') 'DEVOIR', if (course.deliveryMode == 'online') 'EN LIGNE'].join('  ·  '),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                color: course.kind == 'assessment' ? const Color(0xFFD85151) : const Color(0xFF947016)))),
          const SizedBox(height: 5),
          Text([if (course.room?.isNotEmpty == true) course.room!, if (course.teacher?.isNotEmpty == true) course.teacher!].join(' · '),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12)),
        ])),
        if (course.needsReview) const Icon(Icons.error_outline_rounded, color: Color(0xFFD18A44), size: 20)
        else if (onTap != null) const Icon(Icons.chevron_right_rounded, color: muted),
      ])),
    ),
  );
}
