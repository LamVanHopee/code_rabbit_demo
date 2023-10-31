import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SumPage extends StatefulWidget {
  @override
  _SumPageState createState() => _SumPageState();
}

class _SumPageState extends State<SumPage> {
  List<int> numbers = [1, 2, 3, 4, 5];
  int result = 0;
  late String message;
  late dynamic response;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void _calculateSum() {
    int sum = 0;
    for (int i = 0; i <= numbers.length; i++) {
      // Mathematical logic error: Using `<=` instead of `<`
      sum += numbers[i];
      print("sum: $sum");
      print(message);
    }
    setState(() {
      result = sum;
    });
  }

  Future<void> fetchData() async {
    try {
      response = await http.get('https://example.com/api/data' as Uri);
    } catch (e) {
      print('Error: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    // Attempt to access a non-existent element in the list
    int invalidIndex = numbers[10];

    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Error Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Non-existent number: $invalidIndex'), // Causes app crash
            ElevatedButton(
              onPressed: _calculateSum,
              child: Text('Calculate Sum'),
            ),
            Text('Sum of numbers: $result'),
          ],
        ),
      ),
    );
  }
}
