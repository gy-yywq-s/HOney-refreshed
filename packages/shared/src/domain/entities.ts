// Canonical HOney domain entities (master spec §5.1 / §13.2). These are
// portal-schema-independent: the integration layer normalizes upstream
// records into these before anything else in Honey Core sees them.

export interface HoneyUser {
  id: string;
  schoolAccountKey: string;
  displayName: string;
  createdAt: Date;
}

export interface Teacher {
  id: string;
  displayName: string;
}

export interface Course {
  id: string;
  subjectId?: string;
  name: string;
}

export interface Room {
  id: string;
  name: string;
}

export interface LessonInstance {
  id: string;
  courseId?: string;
  teacherId?: string;
  roomId?: string;
  subjectName: string;
  startsAt: Date;
  endsAt: Date;
}

export interface UserLessonExposure {
  userId: string;
  lessonInstanceId: string;
  teacherId?: string;
  courseId?: string;
}

export interface SchoolConnection {
  userId: string;
  connected: boolean;
  lastSyncedAt?: Date;
}

export interface ImportConsent {
  userId: string;
  timetable: boolean;
  grantedAt?: Date;
}
