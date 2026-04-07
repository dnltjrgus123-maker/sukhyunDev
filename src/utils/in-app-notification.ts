import type { NotificationType as DbNotificationType } from "@prisma/client";
import { Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import type { NotificationType } from "../data/store.js";

export async function pushInAppNotification(
  userId: string,
  type: NotificationType,
  payload: Record<string, unknown>
): Promise<void> {
  await prisma.notification.create({
    data: {
      userId,
      type: type as DbNotificationType,
      payload: payload as Prisma.InputJsonValue
    }
  });
}
