import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class test1 extends StatefulWidget {
  @override
  _test1State createState() => _test1State();
}

class _test1State extends State<test1> {
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
