class Attendance {
  final String className;
  final String classTime;
  final String status;
  final String date;
  final String studentName; // ✅ new field

  Attendance({
    required this.className,
    required this.classTime,
    required this.status,
    required this.date,
    required this.studentName, // ✅ new field
  });

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      className: map['className'] ?? '',
      classTime: map['classTime'] ?? '',
      status: map['status'] ?? '',
      date: map['date'] ?? '',
      studentName: map['studentName'] ?? 'Unknown', // default
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'className': className,
      'classTime': classTime,
      'status': status,
      'date': date,
      'studentName': studentName, // include it
    };
  }
}
