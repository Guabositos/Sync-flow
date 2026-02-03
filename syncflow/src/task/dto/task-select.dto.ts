import { FindOptionsSelect } from 'typeorm';
import { Task } from '../entities/task.entity';

export const TaskSelectOptions: FindOptionsSelect<Task> = {
  id: true,
  title: true,
  description: true,
  dueDate: true,
  completed: true,
  createdAt: true,
  company: {
    id: true
  },
  assignedTo: {
    id: true,
    username: true
  }
}; 