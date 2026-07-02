<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

require 'db.php';

$method = $_SERVER["REQUEST_METHOD"];
$action = $_GET['action'] ?? '';

// Mixed Input Handling (JSON + POST/Files)
$json_input = file_get_contents("php://input");
$data = json_decode($json_input, true) ?? $_POST;

/* ========================= SCHEDULE MANAGEMENT (POST) ========================= */
if ($method == 'POST' && $action == 'add_schedule') {
    try {
        $stmt = $pdo->prepare("INSERT INTO schedules (day, time, subject, batch, teacher_id) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([
            $data['day'],
            $data['time'],
            $data['subject'],
            $data['batch'],
            $data['teacher_id']
        ]);
        echo json_encode(["success" => true, "message" => "Schedule created successfully"]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
    }
    exit;
}

if ($method == 'POST' && $action == 'delete_schedule') {
    try {
        $stmt = $pdo->prepare("DELETE FROM schedules WHERE id = ?");
        $stmt->execute([$data['id']]);
        echo json_encode(["success" => true, "message" => "Deleted"]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
    exit;
}

/* ========================= REGISTER API ========================= */
if ($method == 'POST' && $action == 'register') {
    if (empty($data['email']) || empty($data['password'])) {
        echo json_encode(["success" => false, "message" => "Fields missing"]);
        exit;
    }
    $type = strtolower($data['userType'] ?? 'user');
    if ($type === "student") $type = "user";

    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$data['email']]);
    if ($stmt->fetch()) {
        echo json_encode(["success" => false, "message" => "Email exists"]);
        exit;
    }

    $hashedPassword = password_hash($data['password'], PASSWORD_BCRYPT);
    try {
        $sql = "INSERT INTO users (email, password, name, contact, address, country, subject, userType, qualification, studentClass) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        $pdo->prepare($sql)->execute([
            $data['email'], $hashedPassword, $data['name'], $data['contact'] ?? null,
            $data['address'] ?? null, $data['country'] ?? null, trim($data['subject'] ?? ''),
            $type, $data['qualification'] ?? null, $data['studentClass'] ?? null
        ]);
        echo json_encode(["success" => true, "message" => "Registration successful"]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Server error"]);
    }
}

/* ========================= ADMIN: REGISTER USER API ========================= */
elseif ($method == 'POST' && $action == 'admin_add_user') {
    // Ye fields exactly aapki RegisterScreen.dart se match karte hain
    $name = $data['name'] ?? '';
    $email = $data['email'] ?? '';
    $password = $data['password'] ?? '123456'; // Default password if admin doesn't provide
    $contact = $data['contact'] ?? null;
    $address = $data['address'] ?? null;
    $type = strtolower($data['userType'] ?? 'user'); // 'user' (student) ya 'teacher'
    $country = $data['country'] ?? 'India';
    $subject = trim($data['subject'] ?? '');
    $qualification = $data['qualification'] ?? null;
    $studentClass = $data['studentClass'] ?? null;

    // Validation: Admin side se bhi email check karna zaroori hai
    if (empty($email) || empty($name)) {
        echo json_encode(["success" => false, "message" => "Name and Email are mandatory"]);
        exit;
    }

    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        echo json_encode(["success" => false, "message" => "This email is already registered"]);
        exit;
    }

    $hashedPassword = password_hash($password, PASSWORD_BCRYPT);

    try {
        $sql = "INSERT INTO users (email, password, name, contact, address, country, subject, userType, qualification, studentClass)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        $pdo->prepare($sql)->execute([
            $email, $hashedPassword, $name, $contact, $address,
            $country, $subject, $type, $qualification, $studentClass
        ]);

        echo json_encode(["success" => true, "message" => "New $type added successfully by Admin"]);
        exit;
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Server Error: " . $e->getMessage()]);
        exit;
    }
}

/* ========================= LOGIN API ========================= */
elseif ($method == 'POST' && $action == 'login') {
    $email = $data['email'] ?? '';
    $password = $data['password'] ?? '';
    $type = strtolower($data['userType'] ?? '');

    // Student ko user ke roop mein handle karne ke liye
    if ($type === "student" || $type === "user") { $type = "user"; }

    // Database query
    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ? AND userType = ?");
    $stmt->execute([$email, $type]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user) {
        // Password hash verification
        if (password_verify($password, $user['password'])) {
            // Password ko security ke liye response se hata do
            unset($user['password']);

            // NULL values ko empty string mein convert karo (Critical Fix)
            foreach ($user as $key => $value) {
                if (is_null($value)) {
                    $user[$key] = "";
                }
            }

            echo json_encode([
                "success" => true,
                "message" => "Welcome " . ($user['name'] ?? 'User'),
                "data" => $user,
                "token" => "sgn_" . bin2hex(random_bytes(8))
            ]);
            exit;
        } else {
            echo json_encode(["success" => false, "message" => "Incorrect password."]);
            exit;
        }
    } else {
        echo json_encode(["success" => false, "message" => "Account not found for role: $type"]);
    }
}

// --- NEW REQUIREMENT: Get Filtered Orders (Add this) ---
elseif ($method == 'GET' && $action == 'get_filtered_orders') {
    $class = trim($_GET['class'] ?? '');
    $subject = trim($_GET['subject_name'] ?? '');

    $stmt = $pdo->prepare("SELECT id, title, price, status, target_class,
                           DATE_FORMAT(created_at, '%d %b %Y') as date
                           FROM study_materials
                           WHERE LOWER(target_class) LIKE LOWER(?)
                           AND LOWER(subject_name) LIKE LOWER(?)");

    // % use karne se partial match bhi ho jayega
    $stmt->execute(["%$class%", "%$subject%"]);
    $materials = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        "success" => true,
        "data" => $materials
    ]);
}
/* ========================= ADD STUDY MATERIAL ========================= */
if ($action == 'add_study_material') {
    // Flutter se aane wala data pakadne ke liye
    $title = $data['title'] ?? null;
    $description = $data['description'] ?? '';
    $price = $data['price'] ?? '0';
    $target_class = $data['target_class'] ?? null;
    $subject_name = $data['subject_name'] ?? null;
    $status = $data['status'] ?? 'Available'; // Default status

    // Validation: Zaroori fields check karein
    if (!$title || !$target_class || !$subject_name) {
        echo json_encode(["success" => false, "message" => "Title, Class, and Subject are required"]);
        exit;
    }

    try {
        $stmt = $pdo->prepare("INSERT INTO study_materials (title, description, price, target_class, subject_name, status) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->execute([
            $title,
            $description,
            $price,
            $target_class,
            $subject_name,
            $status
        ]);

        echo json_encode(["success" => true, "message" => "Study material added successfully"]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Database Error: " . $e->getMessage()]);
    }
    exit;
}// POST section mein:
if ($action == 'update_study_material') {
    $stmt = $pdo->prepare("UPDATE study_materials SET title=?, description=?, price=?, target_class=?, subject_name=?, status=? WHERE id=?");
    $stmt->execute([$data['title'], $data['description'], $data['price'], $data['target_class'], $data['subject_name'], $data['status'], $data['id']]);
    echo json_encode(["success" => true]);
    exit;
}

if ($action == 'delete_study_material') {
    $stmt = $pdo->prepare("DELETE FROM study_materials WHERE id = ?");
    $stmt->execute([$data['id']]);
    echo json_encode(["success" => true]);
    exit;
}// api.php mein ye add karein agar nahi hai toh
if ($action == 'get_classes_and_subjects') {
    echo json_encode([
        "success" => true,
        "classes" => ["Class 9th", "Class 10th", "Class 11th", "Class 12th"],
        "subjects" => ["Mathematics", "Physics", "Chemistry", "Biology", "Computer Science"]
    ]);
    exit;
}

/* ========================= GET ALL USERS API ========================= */
if ($method == 'GET' && $action == 'get_all_users') {
    try {
        // FIX: 'contact' aur 'address' columns ko query mein add kiya gaya hai
        $stmt = $pdo->prepare("SELECT id, name, email, contact, address, userType, studentClass, subject, qualification FROM users WHERE userType != 'admin' ORDER BY id DESC");
        $stmt->execute();
        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // NULL values ko empty string mein badalna (taaki Flutter crash na ho)
        foreach ($users as &$user) {
            foreach ($user as $key => $value) {
                if (is_null($value)) {
                    $user[$key] = "";
                }
            }
        }

        echo json_encode([
            "success" => true,
            "data" => $users
        ]);
    } catch (Exception $e) {
        echo json_encode([
            "success" => false,
            "message" => "Database error: " . $e->getMessage()
        ]);
    }
}

/* ========================= PLACE ORDER API ========================= */
// Jab student Store se "Buy" dabayega
elseif ($method == 'POST' && $action == 'place_order') {
    $user_id = $data['user_id'] ?? null;
    $material_id = $data['material_id'] ?? null;

    if (!$user_id || !$material_id) {
        echo json_encode(["success" => false, "message" => "Missing data"]);
        exit;
    }

    try {
        $stmt = $pdo->prepare("INSERT INTO orders (user_id, material_id) VALUES (?, ?)");
        $stmt->execute([$user_id, $material_id]);
        echo json_encode(["success" => true, "message" => "Order placed successfully"]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Failed to place order"]);
    }
}

/* ========================= UPDATE PROFILE API ========================= */
elseif ($method == 'POST' && $action == 'update-profile') {
    $id = $data['id'] ?? null;
    $name = $data['name'] ?? null;
    $contact = $data['contact'] ?? null;
    $address = $data['address'] ?? null;
    $qualification = $data['qualification'] ?? null;

    if (!$id || !$name) {
        echo json_encode(["success" => false, "message" => "Required fields missing"]);
        exit;
    }

    try {
        $stmt = $pdo->prepare("UPDATE users SET name = ?, contact = ?, address = ?, qualification = ? WHERE id = ?");
        $stmt->execute([$name, $contact, $address, $qualification, $id]);
        echo json_encode(["success" => true, "message" => "Profile updated successfully"]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
}

/* ========================= CHANGE PASSWORD API ========================= */
elseif ($method == 'POST' && $action == 'change-password') {
    $user_id = $data['user_id'] ?? null;
    $old_password = $data['old_password'] ?? null;
    $new_password = $data['new_password'] ?? null;

    if (!$user_id || !$old_password || !$new_password) {
        echo json_encode(["success" => false, "message" => "Required fields missing"]);
        exit;
    }

    try {
        $stmt = $pdo->prepare("SELECT password FROM users WHERE id = ?");
        $stmt->execute([$user_id]);
        $user = $stmt->fetch();

        if ($user) {
            if (password_verify($old_password, $user['password'])) {
                $newHashedPassword = password_hash($new_password, PASSWORD_BCRYPT);
                $updateStmt = $pdo->prepare("UPDATE users SET password = ? WHERE id = ?");
                $updateStmt->execute([$newHashedPassword, $user_id]);
                echo json_encode(["success" => true, "message" => "Password updated successfully"]);
            } else {
                echo json_encode(["success" => false, "message" => "Please enter correct password"]);
            }
        } else {
            echo json_encode(["success" => false, "message" => "User not found"]);
        }
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Server error"]);
    }
}

/* ========================= UPLOAD PROFILE PIC API ========================= */
elseif ($method == 'POST' && $action == 'upload-profile-pic') {
    $user_id = $_POST['user_id'] ?? null;
    if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
        $upload_dir = 'uploads/profiles/';
        if (!is_dir($upload_dir)) mkdir($upload_dir, 0777, true);
        $file_name = time() . '_' . preg_replace("/[^a-zA-Z0-9.]/", "_", basename($_FILES['image']['name']));
        if (move_uploaded_file($_FILES['image']['tmp_name'], $upload_dir . $file_name)) {
            $pdo->prepare("UPDATE users SET profile_pic = ? WHERE id = ?")->execute([$file_name, $user_id]);
            echo json_encode(["success" => true, "profile_pic" => $file_name]);
        }
    }
}

/* ========================= DELETE PROFILE PIC API ========================= */
elseif ($method == 'POST' && $action == 'delete-profile-pic') {
    $user_id = $data['user_id'] ?? null;
    try {
        $stmt = $pdo->prepare("SELECT profile_pic FROM users WHERE id = ?");
        $stmt->execute([$user_id]);
        $row = $stmt->fetch();
        if ($row && !empty($row['profile_pic'])) {
            $file_path = 'uploads/profiles/' . $row['profile_pic'];
            if (file_exists($file_path)) unlink($file_path);
        }
        $pdo->prepare("UPDATE users SET profile_pic = NULL WHERE id = ?")->execute([$user_id]);
        echo json_encode(["success" => true]);
    } catch (Exception $e) { echo json_encode(["success" => false]); }
}

/* ========================= CREATE ASSIGNMENT API ========================= */
elseif ($method == 'POST' && $action == 'create-assignment') {
    $teacher_id = $_POST['teacher_id'];
    $teacher_name = $_POST['teacher_name'];
    $title = $_POST['title'];
    $subject = $_POST['subject'];
    $class_name = $_POST['class_name'];
    $due_date = $_POST['due_date'];

    $file_name = "none";
    if (isset($_FILES['file']) && $_FILES['file']['error'] === UPLOAD_ERR_OK) {
        $upload_dir = 'uploads/';
        if (!is_dir($upload_dir)) mkdir($upload_dir, 0777, true);
        $file_name = time() . '_' . preg_replace("/[^a-zA-Z0-9.]/", "_", basename($_FILES['file']['name']));
        move_uploaded_file($_FILES['file']['tmp_name'], $upload_dir . $file_name);
    }

    try {
        $pdo->beginTransaction();
        $stmt = $pdo->prepare("INSERT INTO upload_api (teacher_id, teacher_name, title, subject, class_name, due_date, file_name) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $stmt->execute([$teacher_id, $teacher_name, $title, $subject, $class_name, $due_date, $file_name]);

        $studentStmt = $pdo->prepare("SELECT id FROM users WHERE studentClass = ? AND userType = 'user'");
        $studentStmt->execute([$class_name]);
        $students = $studentStmt->fetchAll();
        foreach ($students as $s) {
            $pdo->prepare("INSERT INTO notifications (student_id, title, message, type) VALUES (?, ?, ?, 'assignment')")->execute([$s['id'], $title, "New assignment by $teacher_name"]);
        }
        $pdo->commit();
        echo json_encode(["success" => true]);
    } catch (Exception $e) { if ($pdo->inTransaction()) $pdo->rollBack(); echo json_encode(["success" => false]); }
}

/* ========================= SUBMIT ASSIGNMENT API ========================= */
elseif ($method == 'POST' && $action == 'submit-assignment') {
    $assignment_id = $_POST['assignment_id'];
    $student_id = $_POST['student_id'];
    $student_name = $_POST['student_name'];

    if (isset($_FILES['file']) && $_FILES['file']['error'] === UPLOAD_ERR_OK) {
        $sub_dir = 'submissions/';
        if (!is_dir($sub_dir)) mkdir($sub_dir, 0777, true);
        $file_name = time() . '_ans_' . preg_replace("/[^a-zA-Z0-9.]/", "_", basename($_FILES['file']['name']));
        move_uploaded_file($_FILES['file']['tmp_name'], $sub_dir . $file_name);

        try {
            $pdo->beginTransaction();
            $pdo->prepare("INSERT INTO submissions (assignment_id, student_id, student_name, submission_file) VALUES (?, ?, ?, ?)")->execute([$assignment_id, $student_id, $student_name, $file_name]);

            $assign = $pdo->prepare("SELECT teacher_id, title FROM upload_api WHERE id = ?");
            $assign->execute([$assignment_id]);
            $aData = $assign->fetch();
            if ($aData) {
                $pdo->prepare("INSERT INTO notifications (student_id, title, message, type) VALUES (?, ?, ?, 'submission')")->execute([$aData['teacher_id'], "New Submission", "$student_name submitted " . $aData['title']]);
            }
            $pdo->commit();
            echo json_encode(["success" => true]);
        } catch (Exception $e) { if ($pdo->inTransaction()) $pdo->rollBack(); echo json_encode(["success" => false]); }
    }
}

/* ========================= AUTO ATTENDANCE ON JOIN ========================= */
elseif ($method == 'POST' && $action == 'mark-join-attendance') {
    // Flutter se json data fetch karna
    $student_id = $data['student_id'] ?? null;
    $meeting_id = $data['meeting_id'] ?? 'General'; // Channel name
    $date = date('Y-m-d');

    if (!$student_id) {
        echo json_encode(["success" => false, "message" => "Student ID missing"]);
        exit;
    }

    try {
        // 1. Check karein kya aaj ki attendance pehle se hi marked hai?
        // Hum subject mein check karenge ki 'Live Class' already marked hai ya nahi
        $checkStmt = $pdo->prepare("SELECT id FROM attendance WHERE student_id = ? AND attendance_date = ? AND subject LIKE 'Live Class%' LIMIT 1");
        $checkStmt->execute([$student_id, $date]);

        if ($checkStmt->fetch()) {
            echo json_encode(["success" => true, "message" => "Attendance already recorded for today."]);
            exit;
        }

        // 2. Student ki details nikalna (Class aur Teacher dhoondne ke liye)
        $userStmt = $pdo->prepare("SELECT studentClass FROM users WHERE id = ? LIMIT 1");
        $userStmt->execute([$student_id]);
        $userData = $userStmt->fetch(PDO::FETCH_ASSOC);

        if (!$userData) {
            echo json_encode(["success" => false, "message" => "Student record not found in users table."]);
            exit;
        }

        $sClass = $userData['studentClass'];

        // 3. Teacher ID nikalna jo is class ko padhata hai
        $teacherStmt = $pdo->prepare("SELECT id FROM users WHERE userType = 'teacher' AND studentClass = ? LIMIT 1");
        $teacherStmt->execute([$sClass]);
        $teacherRow = $teacherStmt->fetch(PDO::FETCH_ASSOC);
        $teacher_id = $teacherRow ? $teacherRow['id'] : 0; // Agar teacher na mile toh 0 set hoga

        // 4. Attendance Table mein INSERT
        // Note: status automatically 'Present' set ho jayega as per your table default
        $sql = "INSERT INTO attendance (student_id, teacher_id, subject, student_class, status, attendance_date)
                VALUES (?, ?, ?, ?, 'Present', ?)";

        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            $student_id,
            $teacher_id,
            "Live Class ($meeting_id)",
            $sClass,
            $date
        ]);

        echo json_encode([
            "success" => true,
            "message" => "Attendance marked for $sClass"
        ]);

    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Server Error: " . $e->getMessage()]);
    }
}

/* ========================= DOUBT & SUPPORT TICKET (POST) ========================= */
elseif ($method == 'POST' && $action == 'send-doubt') {
    try {
        $pdo->prepare("INSERT INTO doubts (student_id, teacher_id, subject, message, status) VALUES (?, ?, ?, ?, 'pending')")->execute([$_POST['student_id'], $_POST['teacher_id'], $_POST['subject'], $_POST['message']]);
        $pdo->prepare("INSERT INTO notifications (student_id, title, message, type) VALUES (?, 'New Doubt', 'Ek student ne doubt pucha hai', 'alert')")
    ->execute([$_POST['teacher_id']]);
        echo json_encode(["success" => true]);
    } catch (Exception $e) { echo json_encode(["success" => false]); }
}

elseif ($method == 'POST' && $action == 'submit-reply') {
    $pdo->prepare("UPDATE doubts SET reply = ?, status = 'solved' WHERE id = ?")->execute([$_POST['reply'], $_POST['doubt_id']]);
    echo json_encode(["success" => true]);
}

elseif ($method == 'POST' && $action == 'raise-ticket') {
    $user_id = $data['user_id'] ?? $data['student_id'];
    $message = $data['message'];
    $stmt = $pdo->prepare("SELECT id FROM support_tickets WHERE user_id = ? AND status = 'open' LIMIT 1");
    $stmt->execute([$user_id]);
    $ticket = $stmt->fetch();
    if ($ticket) {
        $pdo->prepare("UPDATE support_tickets SET message = CONCAT(message, ' | ', ?) WHERE id = ?")->execute([$message, $ticket['id']]);
    } else {
        $pdo->prepare("INSERT INTO support_tickets (user_id, user_type, user_name, admin_id, message, status) SELECT id, userType, name, 1, ?, 'open' FROM users WHERE id = ?")->execute([$message, $user_id]);
    }
    echo json_encode(["success" => true]);
}

/* ========================= ADMIN: UPDATE USER API ========================= */
elseif ($method == 'POST' && $action == 'update_user') {
    $id = $data['id'] ?? null;
    $name = $data['name'] ?? null;
    $email = $data['email'] ?? null;
    $contact = $data['contact'] ?? null;
    $address = $data['address'] ?? null;
    $studentClass = $data['studentClass'] ?? null;
    $subject = $data['subject'] ?? null;
    $qualification = $data['qualification'] ?? null;

    if (!$id) {
        echo json_encode(["success" => false, "message" => "User ID missing"]);
        exit;
    }

    try {
        $stmt = $pdo->prepare("UPDATE users SET name = ?, email = ?, contact = ?, address = ?, studentClass = ?, subject = ?, qualification = ? WHERE id = ?");
        $stmt->execute([$name, $email, $contact, $address, $studentClass, $subject, $qualification, $id]);
        echo json_encode(["success" => true, "message" => "User updated successfully"]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
}

/* ========================= ADMIN: DELETE USER API ========================= */
elseif ($method == 'POST' && $action == 'delete_user') {
    $id = $data['id'] ?? null;

    if (!$id) {
        echo json_encode(["success" => false, "message" => "User ID missing"]);
        exit;
    }

    try {
        // User ko database se permanent delete karne ke liye
        $stmt = $pdo->prepare("DELETE FROM users WHERE id = ?");
        $stmt->execute([$id]);

        if ($stmt->rowCount() > 0) {
            echo json_encode(["success" => true, "message" => "User deleted successfully"]);
        } else {
            echo json_encode(["success" => false, "message" => "User not found or already deleted"]);
        }
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
    }
}

/* ========================= SUBMIT TEACHER FEEDBACK ========================= */
elseif ($method == 'POST' && $action == 'submit-teacher-feedback') {
    $student_id = $data['student_id'] ?? null;
    $teacher_id = $data['teacher_id'] ?? null;
    $student_class = $data['student_class'] ?? null;
    $message = $data['message'] ?? '';
    $rating = $data['rating'] ?? 1; // Default 1 (kyunki Flutter mein bhi default 1 hai)

    if (!$student_id || !$teacher_id || empty($message)) {
        echo json_encode(["success" => false, "message" => "Required data missing"]);
        exit;
    }

    try {
        // --- STEP 1: Check if feedback was already sent in the last 15 days ---
        // 'submission_date' ya 'created_at' jo bhi aapke table ka column name hai wo use karein
        $checkStmt = $pdo->prepare("SELECT id FROM teacher_feedback
                                    WHERE student_id = ?
                                    AND teacher_id = ?
                                    AND created_at > DATE_SUB(NOW(), INTERVAL 15 DAY)
                                    LIMIT 1");
        $checkStmt->execute([$student_id, $teacher_id]);

        if ($checkStmt->fetch()) {
            echo json_encode([
                "success" => false,
                "message" => "You can send only one feedback in last 15 days."
            ]);
            exit;
        }

        // --- STEP 2: Insert if limit not reached ---
        $stmt = $pdo->prepare("INSERT INTO teacher_feedback (student_id, teacher_id, student_class, feedback_text, rating) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([$student_id, $teacher_id, $student_class, $message, $rating]);

        echo json_encode(["success" => true, "message" => "Feedback with $rating stars sent to admin"]);

    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
    }
}

/* ========================= ADD PRACTICE QUESTION ========================= */
// Ye POST section mein jayega (jahan register/login hai)
if ($method == 'POST' && $action == 'add_practice_question') {
    try {
        $stmt = $pdo->prepare("INSERT INTO practice_questions (category, question_text, answer_text) VALUES (?, ?, ?)");
        $stmt->execute([
            $data['category'],
            $data['question_text'],
            $data['answer_text']
        ]);
        echo json_encode(["success" => true, "message" => "Question added successfully"]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
    }
    exit;
}elseif ($action == 'update_practice_question') {
    $stmt = $pdo->prepare("UPDATE practice_questions SET category = ?, question_text = ?, answer_text = ? WHERE id = ?");
    $stmt->execute([$data['category'], $data['question_text'], $data['answer_text'], $data['id']]);
    echo json_encode(["success" => true, "message" => "Question updated"]);
    exit;
}elseif ($action == 'delete_question') {
    $id = $data['id'] ?? $_POST['id'];
    $stmt = $pdo->prepare("DELETE FROM practice_questions WHERE id = ?");
    $stmt->execute([$id]);
    echo json_encode(["success" => true, "message" => "Deleted ID: $id"]);
    exit;
}

/* ========================= GET ROUTES ========================= */
elseif ($method == 'GET') {
    switch ($action) {
        // --- ADDED: FAQ ACTION (DATABASE SCHEMA ALIGNED) ---
            case 'get_all_schedules':
            try {
                $sql = "SELECT s.*, u.name as teacher_name
                        FROM schedules s
                        LEFT JOIN users u ON s.teacher_id = u.id
                        ORDER BY id DESC";
                $stmt = $pdo->prepare($sql);
                $stmt->execute();
                echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
            } catch (Exception $e) {
                echo json_encode(["success" => false, "message" => $e->getMessage()]);
            }
            break;

        case 'get-faqs':
            $type = $_GET['type'] ?? 'user';
            $stmt = $pdo->prepare("SELECT question, answer FROM faqs WHERE faq_type = ? ORDER BY id ASC");
            $stmt->execute([$type]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
            break;

        case 'get-matched-teachers':
            $stmt = $pdo->prepare("SELECT id as teacher_id, name as teacher_name, subject, studentClass FROM users WHERE userType = 'teacher' AND studentClass = ? AND subject = ?");
            $stmt->execute([$_GET['studentClass'], $_GET['studentSubject']]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
            break;

      case 'get-student-assignments':
    $student_id = $_GET['student_id'] ?? '';
    $class_name = $_GET['class_name'] ?? '';
    $subject = $_GET['subject'] ?? '';

    // LEFT JOIN se hum assignment ke saath us student ki file nikal rahe hain
    $stmt = $pdo->prepare("
        SELECT
            a.*,
            s.submission_file,
            IF(s.id IS NOT NULL, 1, 0) as is_submitted
        FROM upload_api a
        LEFT JOIN submissions s ON a.id = s.assignment_id AND s.student_id = ?
        WHERE a.class_name = ? AND a.subject = ?
        ORDER BY a.uploaded_at DESC
    ");

    $stmt->execute([$student_id, $class_name, $subject]);
    echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    break;

       case 'get-my-class-teacher':
    $studentClass = $_GET['studentClass'] ?? '';

    // Hum users table se wahi teacher nikal rahe hain jiski studentClass match karti ho
    $stmt = $pdo->prepare("SELECT id as teacher_id, name as teacher_name FROM users WHERE userType = 'teacher' AND studentClass = ? LIMIT 1");
    $stmt->execute([$studentClass]);
    $teacher = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($teacher) {
        echo json_encode(["success" => true, "data" => $teacher]);
    } else {
        echo json_encode(["success" => false, "message" => "No teacher assigned to this class"]);
    }
    break;

        case 'get-my-assignments':
            $stmt = $pdo->prepare("SELECT * FROM upload_api WHERE teacher_id = ? ORDER BY uploaded_at DESC");
            $stmt->execute([$_GET['teacher_id']]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
            break;

        case 'get_all_feedbacks':
    try {
        // Aapke table name 'teacher_feedback' ke hisaab se query
        $sql = "SELECT tf.*,
                       u_t.name as teacher_name,
                       u_s.name as student_name
                FROM teacher_feedback tf
                LEFT JOIN users u_t ON tf.teacher_id = u_t.id
                LEFT JOIN users u_s ON tf.student_id = u_s.id
                ORDER BY tf.created_at DESC";

        $stmt = $pdo->prepare($sql);
        $stmt->execute();
        $feedbacks = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode(["success" => true, "data" => $feedbacks]);
    } catch (PDOException $e) {
        echo json_encode(["success" => false, "message" => "Server Error: " . $e->getMessage()]);
    }
    break;

    case 'get_all_study_materials':
    try {
        $stmt = $pdo->query("SELECT * FROM study_materials ORDER BY id DESC");
        echo json_encode([
            "success" => true,
            "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)
        ]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
    break;



        case 'get-submissions':
            $stmt = $pdo->prepare("SELECT * FROM submissions WHERE assignment_id = ? ORDER BY submitted_at DESC");
            $stmt->execute([$_GET['assignment_id']]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
            break;

        case 'get-my-tickets':
            $stmt = $pdo->prepare("SELECT * FROM support_tickets WHERE user_id = ? ORDER BY created_at DESC");
            $stmt->execute([$_GET['user_id'] ?? $_GET['student_id']]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
            break;

        case 'get-notifications':
            $stmt = $pdo->prepare("SELECT * FROM notifications WHERE student_id = ? ORDER BY created_at DESC");
            $stmt->execute([$_GET['user_id']]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
            break;
        case 'get-my-doubts':
    $stmt = $pdo->prepare("SELECT * FROM doubts WHERE student_id = ? ORDER BY created_at DESC");
    $stmt->execute([$_GET['student_id']]);
    echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
    break;

        case 'get-teacher-doubts':
            $stmt = $pdo->prepare("SELECT d.*, u.name as student_name FROM doubts d JOIN users u ON d.student_id = u.id WHERE d.teacher_id = ? ORDER BY d.created_at DESC");
            $stmt->execute([$_GET['teacher_id']]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
            break;

        case 'my-students':
            $stmt = $pdo->prepare("SELECT id, name, email, contact, studentClass, subject FROM users WHERE userType = 'user' AND subject = ? AND studentClass = ?");
            $stmt->execute([trim($_GET['subject']), trim($_GET['studentClass'])]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll()]);
            break;

        case 'delete-assignment':
            $pdo->prepare("DELETE FROM upload_api WHERE id = ?")->execute([$_GET['id']]);
            echo json_encode(["success" => true]);
            break;
            case 'delete-notification':
            $id = $_GET['id'] ?? null;
            if ($id) {
                try {
                    $pdo->prepare("DELETE FROM notifications WHERE id = ?")->execute([$id]);
                    echo json_encode(["success" => true, "message" => "Deleted"]);
                } catch (Exception $e) {
                    echo json_encode(["success" => false, "message" => "Delete failed"]);
                }
            } else {
                echo json_encode(["success" => false, "message" => "ID missing"]);
            }
            break;

            /* ========================= GET SCHEDULE API ========================= */
case 'get-schedule':
    $day = $_GET['day'] ?? '';
    $subject = trim($_GET['subject'] ?? '');
    $batch = trim($_GET['studentClass'] ?? '');

    if (empty($day) || empty($subject) || empty($batch)) {
        echo json_encode(["success" => false, "message" => "Parameters missing"]);
        break;
    }

    try {
        // Hum database se wahi schedule nikal rahe hain jo teacher ke subject aur class se match kare
        $stmt = $pdo->prepare("SELECT time, subject, batch FROM schedules WHERE day = ? AND subject = ? AND batch = ? ORDER BY id ASC");
        $stmt->execute([$day, $subject, $batch]);
        $schedule = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode([
            "success" => true,
            "data" => $schedule
        ]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Database error"]);
    }
    break;

        case 'get-my-orders':
            $user_id = $_GET['user_id'] ?? null;
            if (!$user_id) {
                echo json_encode(["success" => false, "message" => "User ID missing"]);
                break;
            }

            // JOIN query: orders aur study_materials table ko joda gaya hai
            $stmt = $pdo->prepare("SELECT sm.title, sm.price, o.status, DATE_FORMAT(o.order_date, '%d %b %Y') as date
                                   FROM orders o
                                   JOIN study_materials sm ON o.material_id = sm.id
                                   WHERE o.user_id = ?
                                   ORDER BY o.order_date DESC");
            $stmt->execute([$user_id]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
            break;




        /* ========================= PRACTICE QUESTIONS API ========================= */
case 'get-practice-tabs':
    try {
        // 1. UNIQUE categories nikalne ke liye GROUP BY use kiya hai
        // Isse "3065 Expression #1 of ORDER BY" wala error fix ho jayega
        $stmt = $pdo->prepare("SELECT category FROM practice_questions GROUP BY category ORDER BY MIN(id) ASC");
        $stmt->execute();
        $categories = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $finalData = [];

        foreach ($categories as $cat) {
            $catName = $cat['category'];

            // 2. Har category ke liye uske questions fetch karte hain
            $qStmt = $pdo->prepare("SELECT question_text as q, answer_text as a FROM practice_questions WHERE category = ? ORDER BY id ASC");
            $qStmt->execute([$catName]);
            $questions = $qStmt->fetchAll(PDO::FETCH_ASSOC);

            // 3. Data ko nest karte hain
            $finalData[] = [
                "category_name" => $catName,
                "questions" => $questions
            ];
        }

        echo json_encode([
            "success" => true,
            "data" => $finalData
        ]);
    } catch (Exception $e) {
        echo json_encode([
            "success" => false,
            "message" => "Database Error: " . $e->getMessage()
        ]);
    }
    break;

        case 'check-attendance-status':
    $subject = $_GET['subject'] ?? '';
    $class = $_GET['studentClass'] ?? '';
    $date = date('Y-m-d');

    $stmt = $pdo->prepare("SELECT id FROM attendance WHERE subject = ? AND student_class = ? AND attendance_date = ? LIMIT 1");
    $stmt->execute([$subject, $class, $date]);

    if ($stmt->fetch()) {
        echo json_encode(["success" => true, "is_submitted" => true]);
    } else {
        echo json_encode(["success" => true, "is_submitted" => false]);
    }
    break;

/* ========================= STUDENT ATTENDANCE HISTORY ========================= */
case 'get-student-attendance':
    $student_id = $_GET['student_id'] ?? '';

    if (empty($student_id)) {
        echo json_encode(["success" => false, "message" => "Student ID missing"]);
        break;
    }

    try {
        // JOIN query: attendance table ko users table se link kiya hai
        // taaki student ka 'name' fetch ho sake.
        $stmt = $pdo->prepare("SELECT
                                a.subject as className,
                                a.student_class as classTime,
                                a.attendance_date as date,
                                a.status,
                                u.name as studentName
                               FROM attendance a
                               INNER JOIN users u ON a.student_id = u.id
                               WHERE a.student_id = ?
                               ORDER BY a.attendance_date DESC, a.id DESC");

        $stmt->execute([$student_id]);
        $attendance = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode([
            "success" => true,
            "data" => $attendance
        ]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
    }
    break;

    /* ========================= ADMIN: GET DASHBOARD STATS ========================= */
case 'get_admin_stats':
    try {
        // 1. Total Students count
        $stmt1 = $pdo->query("SELECT COUNT(*) as total FROM users WHERE userType = 'user'");
        $students = $stmt1->fetch()['total'];

        // 2. Total Teachers count
        $stmt2 = $pdo->query("SELECT COUNT(*) as total FROM users WHERE userType = 'teacher'");
        $teachers = $stmt2->fetch()['total'];

        // 3. Total Study Materials count
        $stmt3 = $pdo->query("SELECT COUNT(*) as total FROM study_materials");
        $materials = $stmt3->fetch()['total'];

        // 4. Pending Doubts count
        $stmt4 = $pdo->query("SELECT COUNT(*) as total FROM doubts WHERE status = 'pending'");
        $doubts = $stmt4->fetch()['total'];

        echo json_encode([
            "success" => true,
            "data" => [
                "total_students" => $students,
                "total_teachers" => $teachers,
                "total_materials" => $materials,
                "pending_doubts" => $doubts
            ]
        ]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
    break;


  case 'get-teacher-history':
    if (!isset($_GET['teacher_id']) || empty($_GET['teacher_id'])) {
        echo json_encode(["success" => false, "message" => "Teacher ID is missing"]);
        break;
    }

    $teacher_id = $_GET['teacher_id'];

    try {
        /* Logic Fix:
           Hum wo records fetch kar rahe hain jahan teacher_id match kare,
           Ya phir wo 'Live Class' wale records jahan student ki class teacher ki class se match kare.
        */
        $sql = "SELECT
                    a.subject as className,
                    a.attendance_date as date,
                    a.status,
                    u.name as studentName,
                    'Live Session' as classTime
                FROM attendance a
                INNER JOIN users u ON a.student_id = u.id
                WHERE a.teacher_id = ?
                OR (a.subject LIKE 'Live Class%' AND a.student_class IN (SELECT studentClass FROM users WHERE id = ?))
                ORDER BY a.attendance_date DESC, a.id DESC";

        $stmt = $pdo->prepare($sql);
        $stmt->execute([$teacher_id, $teacher_id]);
        $history = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode([
            "success" => true,
            "data" => $history
        ]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
    }
    break;

    case 'update_user':
    // Flutter se aane wala JSON data read karein
    $data = json_decode(file_get_contents("php://input"), true);

    if (isset($data['id'])) {
        $id = $data['id'];
        $name = $data['name'];
        $email = $data['email'];
        $contact = $data['contact'];
        $address = $data['address'];
        $studentClass = $data['studentClass'];
        $subject = $data['subject'];
        $qualification = isset($data['qualification']) ? $data['qualification'] : null;

        // SQL Update Query
        $sql = "UPDATE users SET
                name = '$name',
                email = '$email',
                contact = '$contact',
                address = '$address',
                studentClass = '$studentClass',
                subject = '$subject',
                qualification = " . ($qualification ? "'$qualification'" : "NULL") . "
                WHERE id = '$id'";

        if ($conn->query($sql) === TRUE) {
            echo json_encode(["success" => true, "message" => "User updated successfully"]);
        } else {
            echo json_encode(["success" => false, "message" => "Error: " . $conn->error]);
        }
    } else {
        echo json_encode(["success" => false, "message" => "User ID is missing"]);
    }
    break;

    /* ========================= GET UNIQUE CATEGORIES ========================= */
case 'get_unique_categories':
    try {
        // Hum unique categories nikal rahe hain dropdown ke liye
        $stmt = $pdo->prepare("SELECT DISTINCT category FROM practice_questions ORDER BY category ASC");
        $stmt->execute();
        $categories = $stmt->fetchAll(PDO::FETCH_COLUMN); // Sirf names nikalne ke liye

        echo json_encode(["success" => true, "data" => $categories]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
    break;

    /* ========================= DELETE QUESTION ========================= */
case 'delete_question':
    // 1. Raw input read karein
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);

    // 2. ID ko check karne ka foolproof tarika
    $id = null;
    if (isset($data['id'])) {
        $id = $data['id'];
    } elseif (isset($_POST['id'])) {
        $id = $_POST['id'];
    }

    if ($id) {
        try {
            // Table aur column ka naam dhyan se check karein (practice_questions aur id)
            $stmt = $pdo->prepare("DELETE FROM practice_questions WHERE id = ?");
            $success = $stmt->execute([$id]);

            if ($success) {
                echo json_encode(["success" => true, "message" => "Deleted ID: $id"]);
            } else {
                echo json_encode(["success" => false, "message" => "Database execute failed"]);
            }
        } catch (Exception $e) {
            echo json_encode(["success" => false, "message" => "PDO Error: " . $e->getMessage()]);
        }
    } else {
        // Agar yahan tak aaya, matlab PHP ko ID nahi mili
        echo json_encode([
            "success" => false,
            "message" => "PHP Error: No ID received",
            "received_data" => $data // Debug ke liye data wapas bhej rahe hain
        ]);
    }
    break;

/* ========================= UPDATE QUESTION ========================= */
case 'update_practice_question':
    try {
        $json = file_get_contents('php://input');
        $data = json_decode($json, true);

        $id = $data['id'] ?? null;
        $category = $data['category'] ?? '';
        $question = $data['question_text'] ?? '';
        $answer = $data['answer_text'] ?? '';

        if ($id && $question) {
            $stmt = $pdo->prepare("UPDATE practice_questions SET category = ?, question_text = ?, answer_text = ? WHERE id = ?");
            $success = $stmt->execute([$category, $question, $answer, $id]);

            if ($success) {
                echo json_encode(["success" => true, "message" => "Question updated"]);
            } else {
                echo json_encode(["success" => false, "message" => "Update failed"]);
            }
        } else {
            echo json_encode(["success" => false, "message" => "Required data missing"]);
        }
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
    break;

    /* ========================= GET ALL QUESTIONS ========================= */
case 'get_practice_questions':
    try {
        // Table name sahi check karein (practice_questions)
        $stmt = $pdo->prepare("SELECT * FROM practice_questions ORDER BY id DESC");
        $stmt->execute();
        $questions = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Yeh line hona bahut zaroori hai, iske bina Response Body empty aayegi
        echo json_encode(["success" => true, "data" => $questions]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
    break;

        case 'mark-read':
    $id = $_GET['id'] ?? null;
    if ($id) {
        $stmt = $pdo->prepare("UPDATE notifications SET is_read = 1 WHERE id = ?");
        $stmt->execute([$id]);
        echo json_encode(["success" => true]);
    } else {
        echo json_encode(["success" => false, "message" => "ID missing"]);
    }
    break;
    }
} else { echo json_encode(["success" => false]); }
?>