import 'package:flutter/material.dart';

class MySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final Function(String) start_Search;
  const MySearchBar(
      {super.key,
      required this.controller,
      required this.onChanged,
      required this.start_Search});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), // Màu bóng với độ trong suốt
            spreadRadius: 1, // Độ lan của bóng
            blurRadius: 10, // Độ mờ của bóng
            offset: const Offset(0, 4), // Dịch chuyển bóng (x, y)
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
              onTap: () {
                start_Search(controller.text);
              },
              child: const Icon(Icons.search, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
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
                onChanged('');
              },
            ),
        ],
      ),
    );
  }
}
