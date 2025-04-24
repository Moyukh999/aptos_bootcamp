module 0xb03599a306423cb3722997ed48a620e3719c68f38c2344b63624f6f6e0200091::LearningRewards 
{
    use aptos_framework::account;
    use aptos_framework::signer;
    use aptos_framework::timestamp;
    use std::vector;
    use std::string::{Self, String};

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_MILESTONE_NOT_FOUND: u64 = 2;
    const E_MILESTONE_ALREADY_EXISTS: u64 = 3;

    /// Represents a learning milestone
    struct Milestone has store, drop, copy {
        id: u64,
        title: String,
        description: String,
        completed: bool,
        reward_tokens: u64
    }

    /// Student's progress and rewards
    struct StudentRecord has key {
        student: address,
        milestones: vector<Milestone>,
        authorized_teachers: vector<address>,
        next_milestone_id: u64,
        total_tokens: u64
    }

    /// Track learning events
    struct LearningEvent has drop, store {
        milestone_id: u64,
        milestone_title: String,
        tokens_rewarded: u64,
        timestamp: u64,
        action_type: String, // "create", "complete"
        actor: address
    }

    struct LearningEventHandle has key {
        events: vector<LearningEvent>
    }

    /// Initialize a student record
    public entry fun create_student_record(student: &signer) {
        let student_addr = signer::address_of(student);
        let record = StudentRecord {
            student: student_addr,
            milestones: vector::empty<Milestone>(),
            authorized_teachers: vector::empty<address>(),
            next_milestone_id: 0,
            total_tokens: 0
        };
        let event_handle = LearningEventHandle {
            events: vector::empty<LearningEvent>()
        };
        vector::push_back(&mut record.authorized_teachers, student_addr);
        move_to(student, record);
        move_to(student, event_handle);
    }

    fun is_authorized(record: &StudentRecord, addr: address): bool {
        let i = 0;
        let len = vector::length(&record.authorized_teachers);
        while (i < len) {
            if (vector::borrow(&record.authorized_teachers, i) == &addr) {
                return true
            };
            i = i + 1;
        };
        false
    }

    public entry fun add_authorized_teacher(
        account: &signer,
        student_addr: address,
        teacher_addr: address
    ) acquires StudentRecord {
        let record = borrow_global_mut<StudentRecord>(student_addr);
        let caller = signer::address_of(account);
        assert!(caller == record.student, E_NOT_AUTHORIZED);
        if (!is_authorized(record, teacher_addr)) {
            vector::push_back(&mut record.authorized_teachers, teacher_addr);
        };
    }

    /// Add milestone (only teacher or student can add)
    public entry fun add_milestone(
        account: &signer,
        student_addr: address,
        title: vector<u8>,
        description: vector<u8>,
        reward_tokens: u64
    ) acquires StudentRecord, LearningEventHandle {
        let record = borrow_global_mut<StudentRecord>(student_addr);
        let caller = signer::address_of(account);
        assert!(is_authorized(record, caller), E_NOT_AUTHORIZED);
        let milestone_id = record.next_milestone_id;
        let milestone = Milestone {
            id: milestone_id,
            title: string::utf8(title),
            description: string::utf8(description),
            completed: false,
            reward_tokens
        };
        vector::push_back(&mut record.milestones, milestone);
        record.next_milestone_id = milestone_id + 1;

        let event_handle = borrow_global_mut<LearningEventHandle>(student_addr);
        vector::push_back(&mut event_handle.events, LearningEvent {
            milestone_id,
            milestone_title: string::utf8(title),
            tokens_rewarded: 0,
            timestamp: timestamp::now_seconds(),
            action_type: string::utf8(b"create"),
            actor: caller
        });
    }

    /// Mark a milestone as completed and reward tokens
    public entry fun complete_milestone(
        account: &signer,
        student_addr: address,
        milestone_id: u64
    ) acquires StudentRecord, LearningEventHandle {
        let record = borrow_global_mut<StudentRecord>(student_addr);
        let caller = signer::address_of(account);
        assert!(is_authorized(record, caller), E_NOT_AUTHORIZED);
        let len = vector::length(&record.milestones);
        let i = 0;
        let idx = len;

        while (i < len) {
            let m = vector::borrow(&record.milestones, i);
            if (m.id == milestone_id) {
                idx = i;
                break
            };
            i = i + 1;
        };
        assert!(idx < len, E_MILESTONE_NOT_FOUND);
        let milestone = vector::borrow_mut(&mut record.milestones, idx);
        milestone.completed = true;
        record.total_tokens = record.total_tokens + milestone.reward_tokens;

        let event_handle = borrow_global_mut<LearningEventHandle>(student_addr);
        vector::push_back(&mut event_handle.events, LearningEvent {
            milestone_id,
            milestone_title: milestone.title,
            tokens_rewarded: milestone.reward_tokens,
            timestamp: timestamp::now_seconds(),
            action_type: string::utf8(b"complete"),
            actor: caller
        });
    }

    /// Get a student's total token balance
    public fun get_total_tokens(student_addr: address): u64 acquires StudentRecord {
        let record = borrow_global<StudentRecord>(student_addr);
        record.total_tokens
    }

    /// Get milestone details
    public fun get_milestone_details(
        student_addr: address,
        milestone_id: u64
    ): (bool, Milestone) acquires StudentRecord {
        let record = borrow_global<StudentRecord>(student_addr);
        let i = 0;
        let len = vector::length(&record.milestones);
        while (i < len) {
            let m = vector::borrow(&record.milestones, i);
            if (m.id == milestone_id) {
                return (true, *m)
            };
            i = i + 1;
        };
        let default = Milestone {
            id: 0,
            title: string::utf8(b""),
            description: string::utf8(b""),
            completed: false,
            reward_tokens: 0
        };
        (false, default)
    }
}
