import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class test2 extends StatefulWidget {
  @override
  _test2State createState() => _test2State();
}

class _test2State extends State<test2> {
  final Uri _url = Uri.parse('https://scriptagher.app/marketplace');

  @override
  void initState() {
    super.initState();
    _launchMarketplace();
  }

  Future<void> _launchMarketplace() async {
    if (await canLaunchUrl(_url)) {
      await launchUrl(_url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il marketplace')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Marketplace')),
      body: Center(
        child: ElevatedButton(
          onPressed: _launchMarketplace,
          child: Text('Apri il marketplace nel browser'),
        ),
      ),
    );
  }
}
