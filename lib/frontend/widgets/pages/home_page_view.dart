import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/gestures.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CarouselSliderController _carouselController = CarouselSliderController();

  final sections = [
    _Section(
      title: 'Portfolio',
      description: 'Visualizza il tuo portafoglio di assets',
      routeName: '/portfolio',
    ),
    _Section(
      title: 'Bot List',
      description: 'Gestisci e configura i tuoi bot',
      routeName: '/bots',
    ),
    _Section(
      title: 'Test1',
      description: 'Gestisci e configura i tuoi bot',
      routeName: '/test1',
    ),
    _Section(
      title: 'Test2',
      description: 'Gestisci e configura i tuoi bot',
      routeName: '/test2',
    ),
    _Section(
      title: 'Test3',
      description: 'Gestisci e configura i tuoi bot',
      routeName: '/test3',
    ),
  ];

  int _currentIndex = 0;

  void _onScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy > 0) {
        // Scroll down -> next slide
        setState(() {
          _currentIndex = (_currentIndex + 1).clamp(0, sections.length - 1);
        });
        _carouselController.animateToPage(
          _currentIndex,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      } else if (event.scrollDelta.dy < 0) {
        // Scroll up -> previous slide
        setState(() {
          _currentIndex = (_currentIndex - 1).clamp(0, sections.length - 1);
        });
        _carouselController.animateToPage(
          _currentIndex,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HOME - Cosa vuoi fare?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 40),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 800,
                  child: Listener(
                    onPointerSignal: _onScroll,
                    child: CarouselSlider.builder(
                      carouselController: _carouselController,
                      itemCount: sections.length,
                      itemBuilder: (context, index, realIdx) {
                        return _SectionCard(section: sections[index]);
                      },
                      options: CarouselOptions(
                        height: 220,
                        enlargeCenterPage: true,
                        enableInfiniteScroll: true,
                        viewportFraction: 0.33,
                        autoPlay: false,
                        scrollDirection: Axis.horizontal,
                        initialPage: _currentIndex,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section {
  final String title;
  final String description;
  final String routeName;

  _Section({
    required this.title,
    required this.description,
    required this.routeName,
  });
}

class _SectionCard extends StatelessWidget {
  final _Section section;

  const _SectionCard({Key? key, required this.section}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, section.routeName),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                section.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
