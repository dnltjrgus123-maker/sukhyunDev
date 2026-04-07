import type { NotificationService } from "./membership.service.js";

export interface NotificationRecord {
  userId: string;
  type: "membership_approved" | "membership_rejected";
  payload: Record<string, unknown>;
  createdAt: Date;
}

export class InMemoryNotificationService implements NotificationService {
  private readonly events: NotificationRecord[] = [];

  async publish(input: {
    userId: string;
    type: "membership_approved" | "membership_rejected";
    payload: Record<string, unknown>;
  }): Promise<void> {
    this.events.push({
      ...input,
      createdAt: new Date()
    });
  }

  list(): NotificationRecord[] {
    return this.events;
  }
}
