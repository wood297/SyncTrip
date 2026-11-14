from dataclasses import dataclass, field


# Store one value with a (logical counter, device ID) timestamp.
@dataclass(frozen=True)
class Register:

    value: str
    stamp: tuple[int, str]

    # Keep the higher counter; break ties by device ID. Reject reused write IDs.
    def merge(self, other: "Register") -> "Register":
        if self.stamp == other.stamp and self.value != other.value:
            raise ValueError("Conflicting values with one write ID: replica ID reused")
        return max((self, other), key=lambda register: register.stamp)


# Store unique members that can be added but never removed.
@dataclass
class GrowOnlySet:
    members: set[str] = field(default_factory=set)

    def add(self, member: str) -> None:
        self.members.add(member)

    def merge(self, other: "GrowOnlySet") -> None:
        self.members.update(other.members)
