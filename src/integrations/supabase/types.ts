export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      accounts: {
        Row: {
          created_at: string
          currency: string
          id: string
          status: string
          user_id: string
        }
        Insert: {
          created_at?: string
          currency?: string
          id?: string
          status?: string
          user_id: string
        }
        Update: {
          created_at?: string
          currency?: string
          id?: string
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      admin_roles: {
        Row: {
          created_at: string
          role: string
          user_id: string
        }
        Insert: {
          created_at?: string
          role?: string
          user_id: string
        }
        Update: {
          created_at?: string
          role?: string
          user_id?: string
        }
        Relationships: []
      }
      app_settings: {
        Row: {
          key: string
          updated_at: string
          value: number
        }
        Insert: {
          key: string
          updated_at?: string
          value: number
        }
        Update: {
          key?: string
          updated_at?: string
          value?: number
        }
        Relationships: []
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          id: string
          target_reference: string | null
          target_user_id: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          id?: string
          target_reference?: string | null
          target_user_id?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          id?: string
          target_reference?: string | null
          target_user_id?: string | null
        }
        Relationships: []
      }
      cn_campaigns: {
        Row: {
          created_at: string
          description: string
          ends_at: string
          id: string
          invest_target: number
          kind: string
          link: string
          max_participations: number
          max_total_entries: number
          paid_at: string | null
          plan_ids: string[]
          prize_type: string
          prizes: number[]
          reward_coins: number
          status: string
          title: string
        }
        Insert: {
          created_at?: string
          description?: string
          ends_at: string
          id?: string
          invest_target?: number
          kind?: string
          link?: string
          max_participations?: number
          max_total_entries?: number
          paid_at?: string | null
          plan_ids?: string[]
          prize_type?: string
          prizes?: number[]
          reward_coins?: number
          status?: string
          title: string
        }
        Update: {
          created_at?: string
          description?: string
          ends_at?: string
          id?: string
          invest_target?: number
          kind?: string
          link?: string
          max_participations?: number
          max_total_entries?: number
          paid_at?: string | null
          plan_ids?: string[]
          prize_type?: string
          prizes?: number[]
          reward_coins?: number
          status?: string
          title?: string
        }
        Relationships: []
      }
      cn_launch_status: {
        Row: {
          cex_listed: boolean
          id: boolean
          tge_completed: boolean
        }
        Insert: {
          cex_listed?: boolean
          id?: boolean
          tge_completed?: boolean
        }
        Update: {
          cex_listed?: boolean
          id?: boolean
          tge_completed?: boolean
        }
        Relationships: []
      }
      cn_rewards: {
        Row: {
          coins: number
          created_at: string
          id: string
          reference: string
          source: string
          user_id: string
        }
        Insert: {
          coins: number
          created_at?: string
          id?: string
          reference: string
          source: string
          user_id: string
        }
        Update: {
          coins?: number
          created_at?: string
          id?: string
          reference?: string
          source?: string
          user_id?: string
        }
        Relationships: []
      }
      cn_share_events: {
        Row: {
          channel: string
          created_at: string
          id: string
          user_id: string
        }
        Insert: {
          channel?: string
          created_at?: string
          id?: string
          user_id: string
        }
        Update: {
          channel?: string
          created_at?: string
          id?: string
          user_id?: string
        }
        Relationships: []
      }
      cn_submissions: {
        Row: {
          campaign_id: string | null
          created_at: string
          id: string
          proof: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          task_id: string | null
          user_id: string
        }
        Insert: {
          campaign_id?: string | null
          created_at?: string
          id?: string
          proof: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          task_id?: string | null
          user_id: string
        }
        Update: {
          campaign_id?: string | null
          created_at?: string
          id?: string
          proof?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          task_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "cn_submissions_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "cn_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cn_submissions_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "cn_tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      cn_tasks: {
        Row: {
          active: boolean
          created_at: string
          description: string
          id: string
          invite_target: number
          kind: string
          link: string
          plan_ids: string[]
          reward_coins: number
          title: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          description?: string
          id?: string
          invite_target?: number
          kind?: string
          link?: string
          plan_ids?: string[]
          reward_coins: number
          title: string
        }
        Update: {
          active?: boolean
          created_at?: string
          description?: string
          id?: string
          invite_target?: number
          kind?: string
          link?: string
          plan_ids?: string[]
          reward_coins?: number
          title?: string
        }
        Relationships: []
      }
      fx_rates: {
        Row: {
          currency: string
          units_per_usd: number
          updated_at: string
        }
        Insert: {
          currency: string
          units_per_usd: number
          updated_at?: string
        }
        Update: {
          currency?: string
          units_per_usd?: number
          updated_at?: string
        }
        Relationships: []
      }
      investment_cycles: {
        Row: {
          created_at: string
          ends_at: string
          id: string
          plan_name: string
          principal_cents: number
          started_at: string
          status: string
          user_id: string
        }
        Insert: {
          created_at?: string
          ends_at: string
          id?: string
          plan_name: string
          principal_cents: number
          started_at?: string
          status?: string
          user_id: string
        }
        Update: {
          created_at?: string
          ends_at?: string
          id?: string
          plan_name?: string
          principal_cents?: number
          started_at?: string
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      investment_plans: {
        Row: {
          active: boolean
          asset: string
          category: string
          cn_reward: number
          created_at: string
          description: string
          earning: number
          estimated_total: number
          hot: boolean
          id: string
          invest: number
          max_investors: number
          name: string
          network: string
          risk: string
          roi_percent: number
          sort_order: number
          status: string
          term_days: number
          updated_at: string
        }
        Insert: {
          active?: boolean
          asset?: string
          category?: string
          cn_reward?: number
          created_at?: string
          description?: string
          earning: number
          estimated_total: number
          hot?: boolean
          id?: string
          invest: number
          max_investors?: number
          name: string
          network?: string
          risk?: string
          roi_percent?: number
          sort_order?: number
          status?: string
          term_days?: number
          updated_at?: string
        }
        Update: {
          active?: boolean
          asset?: string
          category?: string
          cn_reward?: number
          created_at?: string
          description?: string
          earning?: number
          estimated_total?: number
          hot?: boolean
          id?: string
          invest?: number
          max_investors?: number
          name?: string
          network?: string
          risk?: string
          roi_percent?: number
          sort_order?: number
          status?: string
          term_days?: number
          updated_at?: string
        }
        Relationships: []
      }
      kyc_reviews: {
        Row: {
          created_at: string
          document_type: string | null
          id: string
          reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          user_id: string
        }
        Insert: {
          created_at?: string
          document_type?: string | null
          id?: string
          reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          user_id: string
        }
        Update: {
          created_at?: string
          document_type?: string | null
          id?: string
          reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      ledger_entries: {
        Row: {
          amount_cents: number
          created_at: string
          description: string
          id: string
          kind: string
          reference_id: string | null
          status: string
          user_id: string
        }
        Insert: {
          amount_cents: number
          created_at?: string
          description?: string
          id?: string
          kind: string
          reference_id?: string | null
          status?: string
          user_id: string
        }
        Update: {
          amount_cents?: number
          created_at?: string
          description?: string
          id?: string
          kind?: string
          reference_id?: string | null
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      login_events: {
        Row: {
          created_at: string
          device: string
          id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          device?: string
          id?: string
          user_id: string
        }
        Update: {
          created_at?: string
          device?: string
          id?: string
          user_id?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          id: string
          title: string
          type: string
          unread: boolean
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          title: string
          type?: string
          unread?: boolean
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          title?: string
          type?: string
          unread?: boolean
          user_id?: string
        }
        Relationships: []
      }
      payment_transactions: {
        Row: {
          country: string
          created_at: string
          credited: boolean
          currency: string
          id: string
          kind: string
          local_amount: number
          marz_uuid: string | null
          method: string
          phone: string | null
          redirect_url: string | null
          status: string
          updated_at: string
          usd_cents: number
          user_id: string
          withdrawal_request_id: string | null
        }
        Insert: {
          country: string
          created_at?: string
          credited?: boolean
          currency: string
          id?: string
          kind: string
          local_amount: number
          marz_uuid?: string | null
          method?: string
          phone?: string | null
          redirect_url?: string | null
          status?: string
          updated_at?: string
          usd_cents: number
          user_id: string
          withdrawal_request_id?: string | null
        }
        Update: {
          country?: string
          created_at?: string
          credited?: boolean
          currency?: string
          id?: string
          kind?: string
          local_amount?: number
          marz_uuid?: string | null
          method?: string
          phone?: string | null
          redirect_url?: string | null
          status?: string
          updated_at?: string
          usd_cents?: number
          user_id?: string
          withdrawal_request_id?: string | null
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          country: string | null
          created_at: string
          full_name: string | null
          phone: string | null
          referral_code: string | null
          referred_by: string | null
          timezone: string | null
          updated_at: string
          user_id: string
          username: string | null
        }
        Insert: {
          avatar_url?: string | null
          country?: string | null
          created_at?: string
          full_name?: string | null
          phone?: string | null
          referral_code?: string | null
          referred_by?: string | null
          timezone?: string | null
          updated_at?: string
          user_id: string
          username?: string | null
        }
        Update: {
          avatar_url?: string | null
          country?: string | null
          created_at?: string
          full_name?: string | null
          phone?: string | null
          referral_code?: string | null
          referred_by?: string | null
          timezone?: string | null
          updated_at?: string
          user_id?: string
          username?: string | null
        }
        Relationships: []
      }
      referral_rewards: {
        Row: {
          amount_cents: number
          created_at: string
          id: string
          referred_id: string
          referrer_id: string
        }
        Insert: {
          amount_cents: number
          created_at?: string
          id?: string
          referred_id: string
          referrer_id: string
        }
        Update: {
          amount_cents?: number
          created_at?: string
          id?: string
          referred_id?: string
          referrer_id?: string
        }
        Relationships: []
      }
      support_messages: {
        Row: {
          created_at: string
          id: string
          message: string
          status: string
          subject: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          message: string
          status?: string
          subject: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          message?: string
          status?: string
          subject?: string
          user_id?: string
        }
        Relationships: []
      }
      user_pins: {
        Row: {
          pin_hash: string
          updated_at: string
          user_id: string
        }
        Insert: {
          pin_hash: string
          updated_at?: string
          user_id: string
        }
        Update: {
          pin_hash?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_restrictions: {
        Row: {
          reason: string | null
          status: string
          updated_at: string
          user_id: string
        }
        Insert: {
          reason?: string | null
          status?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          reason?: string | null
          status?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      withdrawal_requests: {
        Row: {
          account_id: string
          amount_cents: number
          destination: string
          id: string
          note: string | null
          paid_at: string | null
          requested_at: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          user_id: string
        }
        Insert: {
          account_id: string
          amount_cents: number
          destination: string
          id?: string
          note?: string | null
          paid_at?: string | null
          requested_at?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          user_id: string
        }
        Update: {
          account_id?: string
          amount_cents?: number
          destination?: string
          id?: string
          note?: string | null
          paid_at?: string | null
          requested_at?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "withdrawal_requests_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_guard: { Args: never; Returns: undefined }
      admin_list_audit: {
        Args: never
        Returns: {
          action: string
          created_at: string
          id: string
          target_reference: string
          target_user_id: string
        }[]
      }
      admin_list_cn_submissions: {
        Args: never
        Returns: {
          created_at: string
          email: string
          id: string
          item: string
          kind: string
          proof: string
          status: string
        }[]
      }
      admin_list_kyc: {
        Args: never
        Returns: {
          created_at: string
          document_type: string
          email: string
          id: string
          status: string
          user_id: string
        }[]
      }
      admin_list_support: {
        Args: never
        Returns: {
          created_at: string
          email: string
          id: string
          message: string
          status: string
          subject: string
        }[]
      }
      admin_list_users: {
        Args: never
        Returns: {
          created_at: string
          email: string
          kyc_status: string
          restriction_status: string
          user_id: string
        }[]
      }
      admin_list_withdrawals: {
        Args: never
        Returns: {
          amount_cents: number
          destination: string
          email: string
          id: string
          requested_at: string
          status: string
          user_id: string
        }[]
      }
      admin_mark_withdrawal_paid: {
        Args: { p_request_id: string }
        Returns: undefined
      }
      admin_move_plan: {
        Args: { p_plan_id: string; p_position: number }
        Returns: undefined
      }
      admin_overview: { Args: never; Returns: Json }
      admin_pay_cn_campaign: { Args: { p_campaign: string }; Returns: number }
      admin_review_cn_submission: {
        Args: { p_id: string; p_status: string }
        Returns: undefined
      }
      admin_review_kyc: {
        Args: { p_reason: string; p_review_id: string; p_status: string }
        Returns: undefined
      }
      admin_review_withdrawal: {
        Args: { p_note: string; p_request_id: string; p_status: string }
        Returns: undefined
      }
      admin_set_fx: {
        Args: { p_currency: string; p_rate: number }
        Returns: undefined
      }
      admin_set_setting: {
        Args: { p_key: string; p_value: number }
        Returns: undefined
      }
      admin_set_user_restriction: {
        Args: { p_reason: string; p_status: string; p_user_id: string }
        Returns: undefined
      }
      available_cents: { Args: { _uid: string }; Returns: number }
      cn_award_investment: {
        Args: { _cycle: string; _plan_name: string; _uid: string }
        Returns: undefined
      }
      cn_board: { Args: never; Returns: Json }
      cn_campaign_scores: {
        Args: { p_campaign: string }
        Returns: {
          last_at: string
          name: string
          score: number
          user_id: string
        }[]
      }
      cn_claim_invite_task: { Args: { p_task: string }; Returns: undefined }
      cn_invest_campaign_count: {
        Args: { _camp: string; _uid: string }
        Returns: number
      }
      cn_invite_progress: { Args: { _uid: string }; Returns: number }
      cn_plan_match: {
        Args: { _ids: string[]; _plan_name: string }
        Returns: boolean
      }
      cn_record_share: { Args: never; Returns: Json }
      cn_share_status: { Args: never; Returns: Json }
      cn_submit_proof: {
        Args: { p_campaign: string; p_proof: string; p_task: string }
        Returns: undefined
      }
      cn_task_eligible: {
        Args: { _task: string; _uid: string }
        Returns: boolean
      }
      credit_deposit: { Args: { p_id: string }; Returns: undefined }
      ensure_account: { Args: never; Returns: undefined }
      finalize_withdrawal: {
        Args: { p_request_id: string; p_success: boolean }
        Returns: undefined
      }
      has_withdrawal_pin: { Args: never; Returns: boolean }
      is_admin: { Args: { _uid: string }; Returns: boolean }
      my_cn_rewards: { Args: never; Returns: Json }
      my_login_events: {
        Args: never
        Returns: {
          created_at: string
          device: string
        }[]
      }
      my_referral_stats: { Args: never; Returns: Json }
      plan_investor_counts: {
        Args: never
        Returns: {
          investors: number
          plan_id: string
        }[]
      }
      record_login_event: { Args: { _device: string }; Returns: undefined }
      set_withdrawal_pin: { Args: { _pin: string }; Returns: undefined }
      settle_my_cycles: { Args: never; Returns: undefined }
      start_investment: { Args: { p_plan_id: string }; Returns: undefined }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
