import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

const shopName = 'MAHALAXMI JUICE CENTER';
const shopAddress = 'Pusesavali, Tal. Khatav, Satara';
final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StoreDb.instance.db;
  runApp(const JuicePosApp());
}

class StoreDb {
  StoreDb._();
  static final instance = StoreDb._();
  Database? _db;
  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'mahalaxmi_juice_pos.db');
    _db = await openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('CREATE TABLE branches(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)');
      await d.execute('CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT, branch_id INTEGER NOT NULL, product TEXT NOT NULL, qty REAL NOT NULL, rate REAL NOT NULL, total REAL NOT NULL, payment TEXT NOT NULL, customer TEXT, created_at TEXT NOT NULL)');
      await d.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, branch_id INTEGER NOT NULL, category TEXT NOT NULL, amount REAL NOT NULL, note TEXT, created_at TEXT NOT NULL)');
      await d.execute('CREATE TABLE stock(id INTEGER PRIMARY KEY AUTOINCREMENT, branch_id INTEGER NOT NULL, item TEXT NOT NULL, quantity REAL NOT NULL, unit TEXT NOT NULL, updated_at TEXT NOT NULL)');
      await d.insert('branches', {'name': 'मुख्य शाखा - पुसेसावळी'});
      for (final item in ['मोसंबी','संत्रा','डाळिंब','सफरचंद','अननस','चिकू','स्ट्रॉबेरी','खजूर','मँगो','मिक्स ज्यूस','लस्सी']) {
        // Product list is managed in the billing screen for this starter release.
      }
    });
    return _db!;
  }
}

class JuicePosApp extends StatelessWidget {
  const JuicePosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: shopName,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff17643b)), useMaterial3: true),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  int branchId = 1, tab = 0;
  String branchName = 'मुख्य शाखा - पुसेसावळी';
  final tabs = const ['बिलिंग','खर्च','स्टॉक','रिपोर्ट'];
  Future<void> manageBranches() async {
    final name = TextEditingController();
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('शाखा व्यवस्थापन'), content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [FutureBuilder(future: StoreDb.instance.db.then((d)=>d.query('branches')), builder: (c,s)=>Column(children: (s.data ?? []).map((r)=>ListTile(title: Text(r['name'].toString()), onTap: () { setState(() { branchId=r['id'] as int; branchName=r['name'] as String; }); Navigator.pop(dialogContext); })).toList())), TextField(controller: name, decoration: const InputDecoration(labelText: 'नवीन शाखेचे नाव'))])), actions: [TextButton(onPressed: ()=>Navigator.pop(dialogContext), child: const Text('बंद')), FilledButton(onPressed: () async { if(name.text.trim().isNotEmpty){ final id=await (await StoreDb.instance.db).insert('branches', {'name':name.text.trim()}); setState((){branchId=id;branchName=name.text.trim();}); } if(dialogContext.mounted) Navigator.pop(dialogContext); }, child: const Text('शाखा जोडा'))]));
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('महालक्ष्मी ज्यूस सेंटर', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(tooltip: 'शाखा बदला / जोडा', icon: const Icon(Icons.store), onPressed: manageBranches)]),
    body: Column(children: [Container(width: double.infinity, color: Theme.of(context).colorScheme.primaryContainer, padding: const EdgeInsets.all(8), child: Text(branchName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: IndexedStack(index: tab, children: [BillingPage(branchId: branchId), ExpensePage(branchId: branchId), StockPage(branchId: branchId), ReportPage(branchId: branchId)] ))]),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v)=>setState(()=>tab=v), destinations: const [NavigationDestination(icon: Icon(Icons.receipt_long), label: 'बिलिंग'), NavigationDestination(icon: Icon(Icons.wallet), label: 'खर्च'), NavigationDestination(icon: Icon(Icons.inventory_2), label: 'स्टॉक'), NavigationDestination(icon: Icon(Icons.analytics), label: 'रिपोर्ट')]),
  );
}

class BillingPage extends StatefulWidget { final int branchId; const BillingPage({super.key, required this.branchId}); @override State<BillingPage> createState()=>_BillingPageState(); }
class _BillingPageState extends State<BillingPage> {
  final products = ['मोसंबी ज्यूस','संत्रा ज्यूस','डाळिंब ज्यूस','ॲपल ज्यूस','अननस ज्यूस','चिकू ज्यूस','स्ट्रॉबेरी ज्यूस','खजूर ज्यूस','मँगो ज्यूस','मिक्स ज्यूस','लस्सी'];
  String product = 'मोसंबी ज्यूस', payment = 'Cash';
  final rate = TextEditingController(text:'30'), qty = TextEditingController(text:'1'), customer = TextEditingController();
  double get total => (double.tryParse(rate.text)??0)*(double.tryParse(qty.text)??0);
  Future<void> saveBill() async {
    if (total <= 0) return;
    final db = await StoreDb.instance.db;
    final created = DateTime.now().toIso8601String();
    final id = await db.insert('sales', {'branch_id':widget.branchId,'product':product,'qty':double.parse(qty.text),'rate':double.parse(rate.text),'total':total,'payment':payment,'customer':customer.text,'created_at':created});
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('बिल #$id सेव झाले'))); }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('बिल सेव झाले. प्रिंटरची गरज नाही.')));
    setState(() { qty.text='1'; customer.clear(); });
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[Text('नवीन बिल',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),TextField(controller:customer,decoration:const InputDecoration(labelText:'ग्राहकाचे नाव (ऐच्छिक)',border:OutlineInputBorder())),const SizedBox(height:12),DropdownButtonFormField(value:product,decoration:const InputDecoration(labelText:'प्रॉडक्ट',border:OutlineInputBorder()),items:products.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>product=v!),),const SizedBox(height:12),Row(children:[Expanded(child:TextField(controller:rate,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'दर ₹',border:OutlineInputBorder()),onChanged:(_)=>setState((){}))),const SizedBox(width:10),Expanded(child:TextField(controller:qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'प्रमाण',border:OutlineInputBorder()),onChanged:(_)=>setState((){})))]),const SizedBox(height:12),DropdownButtonFormField(value:payment,decoration:const InputDecoration(labelText:'पेमेंट प्रकार',border:OutlineInputBorder()),items:const ['Cash','UPI','Credit'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>payment=v!)),const SizedBox(height:18),Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[const Text('एकूण बिल'),Text(money.format(total),style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold,color:Colors.green))]))),FilledButton.icon(onPressed:saveBill,icon:const Icon(Icons.save),label:const Text('बिल सेव करा'))]);
}

class ExpensePage extends StatefulWidget { final int branchId; const ExpensePage({super.key,required this.branchId}); @override State<ExpensePage> createState()=>_ExpensePageState(); }
class _ExpensePageState extends State<ExpensePage>{ final amount=TextEditingController(), note=TextEditingController(); String category='फळे खरेदी'; final cats=['फळे खरेदी','दूध / साखर','बर्फ','ग्लास / साहित्य','वीज बिल','कामगार पगार','दुकान भाडे','इतर खर्च']; Future<void> save() async {final a=double.tryParse(amount.text)??0;if(a<=0)return;await (await StoreDb.instance.db).insert('expenses',{'branch_id':widget.branchId,'category':category,'amount':a,'note':note.text,'created_at':DateTime.now().toIso8601String()});amount.clear();note.clear();setState((){});} @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[Text('खर्च नोंदवा',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),DropdownButtonFormField(value:category,items:cats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v!),decoration:const InputDecoration(labelText:'खर्चाचा प्रकार',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'रक्कम ₹',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:note,decoration:const InputDecoration(labelText:'तपशील',border:OutlineInputBorder())),const SizedBox(height:12),FilledButton(onPressed:save,child:const Text('खर्च सेव करा'))]);}

class StockPage extends StatefulWidget { final int branchId; const StockPage({super.key,required this.branchId}); @override State<StockPage> createState()=>_StockPageState(); }
class _StockPageState extends State<StockPage>{final item=TextEditingController(), qty=TextEditingController(), unit=TextEditingController(text:'किलो');Future<void> add()async{if(item.text.trim().isEmpty||(double.tryParse(qty.text)??0)<=0)return;await(await StoreDb.instance.db).insert('stock',{'branch_id':widget.branchId,'item':item.text,'quantity':double.parse(qty.text),'unit':unit.text,'updated_at':DateTime.now().toIso8601String()});item.clear();qty.clear();setState((){});} @override Widget build(BuildContext context)=>FutureBuilder(future:StoreDb.instance.db.then((d)=>d.query('stock',where:'branch_id=?',whereArgs:[widget.branchId],orderBy:'item')),builder:(c,s)=>ListView(padding:const EdgeInsets.all(16),children:[Text('स्टॉक व्यवस्थापन',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:10),TextField(controller:item,decoration:const InputDecoration(labelText:'वस्तूचे नाव',border:OutlineInputBorder())),const SizedBox(height:8),Row(children:[Expanded(child:TextField(controller:qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'प्रमाण',border:OutlineInputBorder()))),const SizedBox(width:8),Expanded(child:TextField(controller:unit,decoration:const InputDecoration(labelText:'एकक',border:OutlineInputBorder())))]),const SizedBox(height:8),FilledButton(onPressed:add,child:const Text('स्टॉक जोडा')),const Divider(),if(s.hasData) ...s.data!.map((r)=>ListTile(title:Text(r['item'].toString()),trailing:Text('${r['quantity']} ${r['unit']}')))]));}

class ReportPage extends StatefulWidget { final int branchId; const ReportPage({super.key,required this.branchId}); @override State<ReportPage> createState()=>_ReportPageState(); }
class _ReportPageState extends State<ReportPage>{@override Widget build(BuildContext context)=>FutureBuilder(future:StoreDb.instance.db.then((d)async{final now=DateTime.now();final start=DateTime(now.year,now.month,now.day).toIso8601String();final end=DateTime(now.year,now.month,now.day,23,59,59).toIso8601String();final s=await d.rawQuery('SELECT COALESCE(SUM(total),0) v, COUNT(*) n FROM sales WHERE branch_id=? AND created_at BETWEEN ? AND ?',[widget.branchId,start,end]);final e=await d.rawQuery('SELECT COALESCE(SUM(amount),0) v FROM expenses WHERE branch_id=? AND created_at BETWEEN ? AND ?',[widget.branchId,start,end]);return {'sales':(s.first['v'] as num).toDouble(),'orders':s.first['n'],'expenses':(e.first['v'] as num).toDouble()};}),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final x=s.data!;final sale=x['sales'] as double, exp=x['expenses'] as double;return ListView(padding:const EdgeInsets.all(16),children:[Text('आजचा रिपोर्ट',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),_metric('आजची विक्री',money.format(sale)),_metric('आजचा खर्च',money.format(exp)),_metric('विक्री वजा खर्च',money.format(sale-exp)),_metric('बिलांची संख्या',x['orders'].toString()),const Padding(padding:EdgeInsets.only(top:12),child:Text('टीप: हा प्राथमिक रोख फरक आहे. मालाचा खर्च/उरलेला स्टॉक, थकबाकी व इतर देणी समाविष्ट नाहीत.'))]);}});}
Widget _metric(String label,String value)=>Card(child:ListTile(title:Text(label),trailing:Text(value,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))));

