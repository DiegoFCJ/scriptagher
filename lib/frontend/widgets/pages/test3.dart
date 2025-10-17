import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class test3 extends StatefulWidget {
  @override
  _test3State createState() => _test3State();
}

class _test3State extends State<test3> {
  final Uri _url = Uri.parse('https://diegofcj.github.io/portfolio/');

  @override
  void initState() {
    super.initState();
    _launchPortfolio();
  }

  Future<void> _launchPortfolio() async {
    if (await canLaunchUrl(_url)) {
      await launchUrl(_url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il portfolio')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Portfolio')),
      body: Center(
        child: ElevatedButton(
          onPressed: _launchPortfolio,
          child: Text('Apri Portfolio nel browser'),
        ),
      ),
    );
  }
}
