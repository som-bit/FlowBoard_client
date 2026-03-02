import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../controllers/boards_controller.dart';

class CreateBoardDialog extends ConsumerStatefulWidget {
  const CreateBoardDialog({super.key});

  @override
  ConsumerState<CreateBoardDialog> createState() => _CreateBoardDialogState();
}

class _CreateBoardDialogState extends ConsumerState<CreateBoardDialog> {
  late TextEditingController _titleController;
  
  // Available palette
  final List<String> _colors = ['#3B82F6', '#EF4444', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899'];
  String _selectedColor = '#3B82F6';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('New Board', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Board Title',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
            ),
          ),
          SizedBox(height: 16.h),
          const Text('COLOR', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),
          // Color Picker Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _colors.map((colorHex) {
              final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
              final isSelected = _selectedColor == colorHex;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorHex),
                child: Container(
                  width: 32.w, height: 32.h,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.white, width: 2.w) : null,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              );
            }).toList(),
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              // Pass the selected color instead of the hardcoded one!
              ref.read(boardsControllerProvider).createNewBoard(_titleController.text.trim(), _selectedColor);
              Navigator.pop(context);
            }
          },
          child: const Text('Create', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}