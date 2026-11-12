import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const RudoshAdminApp());
}

class RudoshAdminApp extends StatelessWidget {
  const RudoshAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مدیریت رودوش',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Tahoma',
      ),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale('fa', 'IR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _urlController = TextEditingController(text: 'https://rudosh.ir');
  final _ckController = TextEditingController();
  final _csController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('site_url');
    final ck = prefs.getString('consumer_key');
    final cs = prefs.getString('consumer_secret');

    if (url != null && ck != null && cs != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(siteUrl: url, consumerKey: ck, consumerSecret: cs),
          ),
        );
      }
    }
  }

  Future<void> _connect() async {
    if (_urlController.text.isEmpty || _ckController.text.isEmpty || _csController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً تمام فیلدها را پر کنید')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = _urlController.text.trim();
      final ck = _ckController.text.trim();
      final cs = _csController.text.trim();

      final response = await http.get(
        Uri.parse('$url/wp-json/wc/v3/system_status'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$ck:$cs'))}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('site_url', url);
        await prefs.setString('consumer_key', ck);
        await prefs.setString('consumer_secret', cs);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(siteUrl: url, consumerKey: ck, consumerSecret: cs),
            ),
          );
        }
      } else {
        throw Exception('خطا در احراز هویت (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('اتصال ناموفق: لطفا کلیدها را بررسی کنید')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ورود به پنل مدیریت رودوش')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 20),
                const Text('مدیریت فروشگاه رودوش', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'آدرس سایت', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _ckController,
                  decoration: const InputDecoration(labelText: 'Consumer Key (ck_...)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _csController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Consumer Secret (cs_...)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _connect,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('اتصال به فروشگاه', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String siteUrl;
  final String consumerKey;
  final String consumerSecret;

  const HomeScreen({
    super.key,
    required this.siteUrl,
    required this.consumerKey,
    required this.consumerSecret,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      OrdersTab(siteUrl: widget.siteUrl, consumerKey: widget.consumerKey, consumerSecret: widget.consumerSecret),
      ProductsTab(siteUrl: widget.siteUrl, consumerKey: widget.consumerKey, consumerSecret: widget.consumerSecret),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'سفارش‌ها'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'محصولات'),
        ],
      ),
    );
  }
}

class OrdersTab extends StatefulWidget {
  final String siteUrl;
  final String consumerKey;
  final String consumerSecret;

  const OrdersTab({super.key, required this.siteUrl, required this.consumerKey, required this.consumerSecret});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.siteUrl}/wp-json/wc/v3/orders?per_page=20'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${widget.consumerKey}:${widget.consumerSecret}'))}',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _orders = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سفارش‌های فروشگاه'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchOrders),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('سفارشی یافت نشد'))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text('سفارش #${order['id']} - ${order['billing']['first_name']} ${order['billing']['last_name']}'),
                        subtitle: Text('مبلغ: ${order['total']} تومان\nوضعیت: ${order['status']}'),
                        trailing: Text(order['date_created'].toString().substring(0, 10)),
                      ),
                    );
                  },
                ),
    );
  }
}

class ProductsTab extends StatefulWidget {
  final String siteUrl;
  final String consumerKey;
  final String consumerSecret;

  const ProductsTab({super.key, required this.siteUrl, required this.consumerKey, required this.consumerSecret});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.siteUrl}/wp-json/wc/v3/products?per_page=20'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${widget.consumerKey}:${widget.consumerSecret}'))}',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _products = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('محصولات فروشگاه')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('محصولی یافت نشد'))
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(product['name'] ?? ''),
                        subtitle: Text('قیمت: ${product['price']} تومان\nموجودی: ${product['stock_status'] == 'instock' ? 'موجود' : 'ناموجود'}'),
                        trailing: Text(product['type'] == 'variable' ? 'متغیر' : 'ساده'),
                      ),
                    );
                  },
                ),
    );
  }
}
