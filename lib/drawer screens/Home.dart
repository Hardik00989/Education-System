import 'package:flutter/material.dart';
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column( mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Text("Drawer Home Screen Coming Soon.....", style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold,
            ),),
          )
        ],
      ),
    );
  }
}
