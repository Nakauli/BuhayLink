import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // --- STATE VARIABLES (Data) ---
  String _name = "aljuncursiga";
  String _email = "aljuncursiga@gmail.com";
  String _aboutMe = "Experienced freelancer with a passion for high-quality work. Specialized in home renovations and quick repairs. Always available for urgent tasks.";
  String _location = "Metro Manila, Philippines";
  bool _isLoadingLocation = false;

  List<String> _skills = ["Carpentry", "Plumbing", "Electrical", "Painting"];

  // --- LOGIC: GET AUTOMATIC LOCATION ---
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // 1. Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permissions are denied");
          return;
        }
      }

      // 2. Get GPS Coordinates
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // 3. Convert to Address (Reverse Geocoding)
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Example: "Santo Tomas, Davao"
        String newLocation = "${place.locality}, ${place.country}";
        
        setState(() {
          _location = newLocation;
        });
        _showSnackBar("Location updated to $newLocation");
      }
    } catch (e) {
      _showSnackBar("Error getting location: $e");
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  // --- LOGIC: EDIT ABOUT ME ---
  void _editAboutMe() {
    TextEditingController controller = TextEditingController(text: _aboutMe);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit About Me"),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _aboutMe = controller.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // --- LOGIC: EDIT SKILLS ---
  void _editSkills() {
    TextEditingController skillController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Manage Skills"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // List of current skills with delete button
                  Wrap(
                    spacing: 8,
                    children: _skills.map((skill) => Chip(
                      label: Text(skill),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setDialogState(() {
                          setState(() => _skills.remove(skill));
                        });
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Input to add new skill
                  TextField(
                    controller: skillController,
                    decoration: InputDecoration(
                      hintText: "Add a new skill",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () {
                          if (skillController.text.isNotEmpty) {
                            setDialogState(() {
                              setState(() => _skills.add(skillController.text));
                            });
                            skillController.clear();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Done"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("My Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              // Add logout logic here
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // --- 1. PROFILE HEADER ---
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.person, size: 60, color: Colors.grey),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(_email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Text("Verified Member", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- 2. STATS ROW ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem("2", "Applied", Icons.work_outline),
                _buildStatItem("0.0", "Rating", Icons.star_border),
                _buildStatItem("0", "Reviews", Icons.chat_bubble_outline),
              ],
            ),

            const SizedBox(height: 24),

            // --- 3. TABS (Visual Only) ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTabBtn("Overview", true)),
                  Expanded(child: _buildTabBtn("Reviews", false)),
                  Expanded(child: _buildTabBtn("Activity", false)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- 4. ABOUT ME SECTION ---
            _buildSectionHeader("About Me", onTap: _editAboutMe),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _aboutMe,
                style: TextStyle(color: Colors.grey[600], height: 1.5),
              ),
            ),

            const SizedBox(height: 24),

            // --- 5. SKILLS SECTION ---
            _buildSectionHeader("Skills", onTap: _editSkills),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _skills.map((skill) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(skill, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- 6. LOCATION SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  // GPS Button
                  IconButton(
                    icon: _isLoadingLocation 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: _getCurrentLocation,
                    tooltip: "Get Current Location",
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(_location, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionHeader(String title, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildTabBtn(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}