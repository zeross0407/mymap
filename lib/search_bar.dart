import 'package:flutter/material.dart';

class MySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode; // Nhận FocusNode từ ngoài vào
  final Function(String) start_Search;

  const MySearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.start_Search,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue[50],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              start_Search(controller.text);
            },
            child: const Icon(Icons.search, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              focusNode: focusNode, // Gắn FocusNode từ ngoài vào đây
              controller: controller,
              onSubmitted: (value) {
                start_Search(value);
              },
              decoration: const InputDecoration(
                hintText: 'Search...',
                border: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                controller.clear();
              },
            ),
        ],
      ),
    );
  }
}
