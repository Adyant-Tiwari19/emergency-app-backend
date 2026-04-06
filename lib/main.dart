import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_app/config.dart'; 
import 'package:flutter_app/staff_login_screen.dart'; // Import the new UI file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: FirebaseConfig.apiKey,
      authDomain: FirebaseConfig.authDomain,
      projectId: FirebaseConfig.projectId,
      storageBucket: FirebaseConfig.storageBucket,
      messagingSenderId: FirebaseConfig.messagingSenderId,
      appId: FirebaseConfig.appId,
      measurementId: FirebaseConfig.measurementId,
    ),
  );
  runApp(const RapidCrisisApp());
}

class RapidCrisisApp extends StatelessWidget {
  const RapidCrisisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthCare Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Inter', // Matches the premium design feel
      ),
      home: const AuthGate(),
    );
  }
}

// --- 1. AUTH GATE (The Traffic Controller) ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If user is NOT logged in, show the new premium login screen
        if (!snapshot.hasData) {
          return const StaffLoginScreen();
        }

        // If user IS logged in, check their role in Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('Users').doc(snapshot.data!.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
            final role = userData?['role'] ?? 'staff';

            // Route based on role
            return role == 'admin' 
                ? const DashboardScreen() 
                : StaffResponderView(uid: snapshot.data!.uid);
          },
        );
      },
    );
  }
}

// --- 2. DISPATCHER DASHBOARD (ADMIN VIEW) ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _selectedIncidentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        title: const Text("🚨 Emergency Dispatch", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Row(
        children: [
          // Sidebar: Incident List
          SizedBox(
            width: 350,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Incidents')
                  .where('status', isNotEqualTo: 'Resolved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                
                if (docs.isEmpty) return const Center(child: Text("No active incidents."));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    bool isSelected = _selectedIncidentId == docs[index].id;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFEFF6FF),
                      onTap: () => setState(() => _selectedIncidentId = docs[index].id),
                      leading: Icon(Icons.warning_amber_rounded, color: isSelected ? Colors.blue : Colors.grey),
                      title: Text("Room ${data['location']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${data['type']} • ${data['status']}"),
                      trailing: const Icon(Icons.chevron_right, size: 16),
                    );
                  },
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          // Main Panel: Incident Details & Dispatch
          Expanded(
            child: _selectedIncidentId == null 
              ? const Center(child: Text("Select an incident to view details and dispatch staff"))
              : IncidentDetailsPanel(incidentId: _selectedIncidentId!),
          )
        ],
      ),
    );
  }
}

// --- 3. DETAILS & STAFF DISPATCH PANEL ---
class IncidentDetailsPanel extends StatelessWidget {
  final String incidentId;
  const IncidentDetailsPanel({super.key, required this.incidentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Incidents').doc(incidentId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
        final data = snapshot.data!.data() as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['type'].toString().toUpperCase(), 
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.redAccent)),
              Text("LOCATION: Room ${data['location']}", 
                  style: const TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.w500)),
              const Divider(height: 60),
              const Text("AVAILABLE RESPONDERS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Staff')
                      .where('isAvailable', isEqualTo: true)
                      .snapshots(),
                  builder: (context, staffSnap) {
                    if (!staffSnap.hasData) return const LinearProgressIndicator();
                    if (staffSnap.data!.docs.isEmpty) return const Text("No staff currently available.");
                    
                    return ListView(
                      children: staffSnap.data!.docs.map((doc) {
                        final staff = doc.data() as Map<String, dynamic>;
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xFFDBEAFE), child: Icon(Icons.person, color: Colors.blue)),
                            title: Text(staff['name'] ?? "Responder"),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                              onPressed: () => _dispatch(doc.id, staff['name']),
                              child: const Text("Dispatch"),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(20)),
                onPressed: () => FirebaseFirestore.instance.collection('Incidents').doc(incidentId).update({'status': 'Resolved'}),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("MARK AS RESOLVED"),
              )
            ],
          ),
        );
      },
    );
  }

  void _dispatch(String staffId, String? name) {
    FirebaseFirestore.instance.collection('Incidents').doc(incidentId).update({
      'status': 'Assigned',
      'assignedStaff': name,
    });
    // Mark staff as busy
    FirebaseFirestore.instance.collection('Staff').doc(staffId).update({'isAvailable': false});
  }
}

// --- 4. STAFF RESPONDER VIEW ---
class StaffResponderView extends StatelessWidget {
  final String uid;
  const StaffResponderView({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Responder Terminal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout), 
            onPressed: () async {
              await FirebaseFirestore.instance.collection('Staff').doc(uid).update({'isAvailable': false});
              await FirebaseAuth.instance.signOut();
            }
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radar_rounded, size: 100, color: Colors.blue),
            const SizedBox(height: 24),
            const Text("Online & Awaiting Dispatch", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("User ID: $uid", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}