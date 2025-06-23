CREATE TABLE "approval_routing" (
	"id" serial PRIMARY KEY NOT NULL,
	"product_id" integer NOT NULL,
	"risk_level" varchar(20) NOT NULL,
	"approver_id" integer NOT NULL,
	"approval_level" integer DEFAULT 1 NOT NULL,
	"is_active" varchar(10) DEFAULT 'true' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "attachments" (
	"id" serial PRIMARY KEY NOT NULL,
	"file_name" varchar(255) NOT NULL,
	"original_name" varchar(255) NOT NULL,
	"file_size" integer NOT NULL,
	"mime_type" varchar(100) NOT NULL,
	"file_content" text,
	"ticket_id" integer,
	"change_id" integer,
	"uploaded_by" integer,
	"uploaded_by_name" text,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "change_approvals" (
	"id" serial PRIMARY KEY NOT NULL,
	"change_id" integer NOT NULL,
	"approver_id" integer NOT NULL,
	"approval_level" integer NOT NULL,
	"status" varchar(20) DEFAULT 'pending' NOT NULL,
	"approved_at" timestamp,
	"comments" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "change_history" (
	"id" serial PRIMARY KEY NOT NULL,
	"change_id" integer NOT NULL,
	"action" varchar(50) NOT NULL,
	"user_id" integer NOT NULL,
	"timestamp" timestamp DEFAULT now() NOT NULL,
	"notes" text,
	"previous_status" varchar(20),
	"new_status" varchar(20)
);
--> statement-breakpoint
CREATE TABLE "changes" (
	"id" serial PRIMARY KEY NOT NULL,
	"title" text NOT NULL,
	"description" text NOT NULL,
	"status" varchar(20) NOT NULL,
	"priority" varchar(20) NOT NULL,
	"category" varchar(50) NOT NULL,
	"product" varchar(100),
	"requested_by" text NOT NULL,
	"approved_by" text,
	"implemented_by" text,
	"planned_date" timestamp,
	"completed_date" timestamp,
	"start_date" timestamp,
	"end_date" timestamp,
	"risk_level" varchar(20) NOT NULL,
	"change_type" varchar(20) DEFAULT 'normal' NOT NULL,
	"rollback_plan" text,
	"approval_token" text,
	"overdue_notification_sent" timestamp,
	"is_overdue" varchar(10) DEFAULT 'false',
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "products" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" varchar(100) NOT NULL,
	"category" varchar(50) NOT NULL,
	"description" text,
	"is_active" varchar(10) DEFAULT 'true' NOT NULL,
	"owner" varchar(100),
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "products_name_unique" UNIQUE("name")
);
--> statement-breakpoint
CREATE TABLE "sessions" (
	"sid" varchar PRIMARY KEY NOT NULL,
	"sess" jsonb NOT NULL,
	"expire" timestamp NOT NULL
);
--> statement-breakpoint
CREATE TABLE "settings" (
	"id" serial PRIMARY KEY NOT NULL,
	"key" varchar(100) NOT NULL,
	"value" text,
	"description" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "settings_key_unique" UNIQUE("key")
);
--> statement-breakpoint
CREATE TABLE "ticket_history" (
	"id" serial PRIMARY KEY NOT NULL,
	"ticket_id" integer NOT NULL,
	"action" varchar(50) NOT NULL,
	"field" varchar(50),
	"old_value" text,
	"new_value" text,
	"user_id" integer NOT NULL,
	"timestamp" timestamp DEFAULT now() NOT NULL,
	"notes" text
);
--> statement-breakpoint
CREATE TABLE "tickets" (
	"id" serial PRIMARY KEY NOT NULL,
	"title" text NOT NULL,
	"description" text NOT NULL,
	"status" varchar(20) NOT NULL,
	"priority" varchar(20) NOT NULL,
	"category" varchar(50) NOT NULL,
	"product" varchar(100),
	"assigned_to" text,
	"requester_id" integer,
	"requester_email" text,
	"requester_name" text,
	"requester_phone" text,
	"requester_department" text,
	"requester_business_unit" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	"first_response_at" timestamp,
	"resolved_at" timestamp,
	"sla_target_response" integer,
	"sla_target_resolution" integer,
	"sla_response_met" varchar(10),
	"sla_resolution_met" varchar(10),
	"approval_status" varchar(20),
	"approved_by" text,
	"approved_at" timestamp,
	"approval_comments" text,
	"approval_token" text
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" serial PRIMARY KEY NOT NULL,
	"username" text NOT NULL,
	"email" text NOT NULL,
	"password" text NOT NULL,
	"role" varchar(20) NOT NULL,
	"name" text NOT NULL,
	"assigned_products" text[],
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "users_username_unique" UNIQUE("username"),
	CONSTRAINT "users_email_unique" UNIQUE("email")
);
--> statement-breakpoint
ALTER TABLE "approval_routing" ADD CONSTRAINT "approval_routing_product_id_products_id_fk" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "approval_routing" ADD CONSTRAINT "approval_routing_approver_id_users_id_fk" FOREIGN KEY ("approver_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_ticket_id_tickets_id_fk" FOREIGN KEY ("ticket_id") REFERENCES "public"."tickets"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_change_id_changes_id_fk" FOREIGN KEY ("change_id") REFERENCES "public"."changes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "change_approvals" ADD CONSTRAINT "change_approvals_change_id_changes_id_fk" FOREIGN KEY ("change_id") REFERENCES "public"."changes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "change_approvals" ADD CONSTRAINT "change_approvals_approver_id_users_id_fk" FOREIGN KEY ("approver_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "change_history" ADD CONSTRAINT "change_history_change_id_changes_id_fk" FOREIGN KEY ("change_id") REFERENCES "public"."changes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "change_history" ADD CONSTRAINT "change_history_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ticket_history" ADD CONSTRAINT "ticket_history_ticket_id_tickets_id_fk" FOREIGN KEY ("ticket_id") REFERENCES "public"."tickets"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ticket_history" ADD CONSTRAINT "ticket_history_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "IDX_session_expire" ON "sessions" USING btree ("expire");