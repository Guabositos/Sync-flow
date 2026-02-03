import '../models/task_model.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class MockData {
  static final managerUser = UserDto(
    id: '1',
    username: 'manager',
    role: 'manager',
    companyName: 'Mock Company',
  );

  static final users = [
    managerUser,
    UserDto(id: '2', username: 'alice', role: 'user'),
    UserDto(id: '3', username: 'bob', role: 'user'),
  ];

  static final tasks = [
    TaskDto(
      id: '1',
      title: 'Prepare report',
      description: 'Prepare the quarterly financial report',
      completed: false,
      dueDate: DateTime.now(),
      assignedTo:AssignedUserDto(
        id: '2',
        username: 'alice',
    ),
    ),
    TaskDto(
      id: '2',
      title: 'Fix UI bugs',
      description: 'Fix all UI bugs reported in the last sprint',
      completed: true,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      assignedTo: AssignedUserDto(
        id: '3',
        username: 'bob',
      ),
    ),
  ];
}
