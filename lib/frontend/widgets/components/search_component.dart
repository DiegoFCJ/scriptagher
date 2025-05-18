import 'package:flutter/material.dart';

class SearchView extends StatefulWidget {
  @override
  _SearchViewState createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  // Controller per la barra di ricerca
  TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cerca Bot'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barra di ricerca
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cerca un bot',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    // Qui andrà il codice per eseguire la ricerca una volta integrato il backend
                    print('Cercando: ${_searchController.text}');
                  },
                ),
              ),
              onChanged: (value) {
                // Gestisci l'input dell'utente se necessario
                print('Ricerca in corso per: $value');
              },
            ),
            SizedBox(height: 20),
            // Un semplice testo che mostra il termine cercato
            Text(
              'Risultati per: ${_searchController.text}',
              style: TextStyle(fontSize: 18),
            ),
            // Altri widget che mostreranno i risultati della ricerca (da aggiungere più tardi)
          ],
        ),
      ),
    );
  }
}
