<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require_once 'config.php';

$method = $_SERVER['REQUEST_METHOD'];
$request = explode('/', trim($_SERVER['PATH_INFO'],'/'));
$input = json_decode(file_get_contents('php://input'), true);

$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($conn->connect_error) {
    die(json_encode(['error' => 'Database connection failed']));
}

switch ($method) {
    case 'GET':
        if (isset($request[0]) && $request[0] === 'interventions') {
            $sql = "SELECT * FROM interventions";
            $result = $conn->query($sql);
            $interventions = [];
            while($row = $result->fetch_assoc()) {
                $row['equipment'] = json_decode($row['equipment']);
                $interventions[] = $row;
            }
            echo json_encode($interventions);
        }
        break;
        
    case 'POST':
        if (isset($request[0]) && $request[0] === 'login') {
            $username = $input['username'];
            $password = $input['password'];
            
            $stmt = $conn->prepare("SELECT * FROM users WHERE username = ?");
            $stmt->bind_param("s", $username);
            $stmt->execute();
            $result = $stmt->get_result();
            
            if ($result->num_rows > 0) {
                $user = $result->fetch_assoc();
                if (password_verify($password, $user['password'])) {
                    echo json_encode(['success' => true]);
                } else {
                    echo json_encode(['error' => 'Invalid credentials']);
                }
            } else {
                echo json_encode(['error' => 'User not found']);
            }
        } 
        elseif (isset($request[0]) && $request[0] === 'interventions') {
            $intervention = $input;
            $equipment = json_encode($intervention['equipment']);
            
            $stmt = $conn->prepare("INSERT INTO interventions (user, matricule, intervention_type, maintenance_type, priority, status, description, start_date, end_date, equipment, created_at, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?)");
            $stmt->bind_param("ssssssssss", 
                $intervention['user'],
                $intervention['matricule'],
                $intervention['interventionType'],
                $intervention['maintenanceType'],
                $intervention['priority'],
                $intervention['status'],
                $intervention['description'],
                $intervention['start'],
                $intervention['end'],
                $equipment,
                $intervention['deviceId']
            );
            
            if ($stmt->execute()) {
                echo json_encode(['success' => true, 'id' => $stmt->insert_id]);
            } else {
                echo json_encode(['error' => 'Failed to save intervention']);
            }
        }
        break;
        
    case 'PUT':
        if (isset($request[0]) && is_numeric($request[0])) {
            $id = $request[0];
            $intervention = $input;
            $equipment = json_encode($intervention['equipment']);
            
            $stmt = $conn->prepare("UPDATE interventions SET user=?, matricule=?, intervention_type=?, maintenance_type=?, priority=?, status=?, description=?, start_date=?, end_date=?, equipment=?, updated_at=NOW(), updated_by=? WHERE id=?");
            $stmt->bind_param("sssssssssssi", 
                $intervention['user'],
                $intervention['matricule'],
                $intervention['interventionType'],
                $intervention['maintenanceType'],
                $intervention['priority'],
                $intervention['status'],
                $intervention['description'],
                $intervention['start'],
                $intervention['end'],
                $equipment,
                $intervention['deviceId'],
                $id
            );
            
            if ($stmt->execute()) {
                echo json_encode(['success' => true]);
            } else {
                echo json_encode(['error' => 'Failed to update intervention']);
            }
        }
        break;
        
    case 'DELETE':
        if (isset($request[0]) && is_numeric($request[0])) {
            $id = $request[0];
            $stmt = $conn->prepare("DELETE FROM interventions WHERE id=?");
            $stmt->bind_param("i", $id);
            
            if ($stmt->execute()) {
                echo json_encode(['success' => true]);
            } else {
                echo json_encode(['error' => 'Failed to delete intervention']);
            }
        }
        break;
}

$conn->close();
?>